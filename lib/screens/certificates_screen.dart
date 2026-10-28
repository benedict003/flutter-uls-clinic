import 'package:flutter/material.dart';

import '../api/clinic_api.dart';
import '../utils/format.dart';
import '../widgets/brand.dart';
import '../widgets/state_views.dart';

class CertificatesScreen extends StatefulWidget {
  const CertificatesScreen({super.key});

  @override
  State<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends State<CertificatesScreen> {
  static const List<String> _statuses = [
    '',
    'Draft',
    'Pending Approval',
    'Returned for Revision',
    'Approved',
  ];

  String _status = '';
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = ClinicApi.instance.certificates();
  }

  void _load(String status) => setState(() {
    _status = status;
    _future = ClinicApi.instance.certificates(status: status);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clinicAppBar('Certificates'),
      body: ClinicBackground(
        veil: 0.97,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: BrandBanner(
                title: 'Medical certificates',
                subtitle: _status.isEmpty ? 'All statuses' : _status,
                image: BrandImages.seal,
                imageHeight: 32,
              ),
            ),
            SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (final s in _statuses)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.isEmpty ? 'All' : s),
                        selected: _status == s,
                        onSelected: (_) => _load(s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _load(_status),
                child: FutureBuilder<List<dynamic>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView();
                    }
                    if (snapshot.hasError) {
                      return ErrorView(
                        error: snapshot.error!,
                        onRetry: () => _load(_status),
                      );
                    }
                    final rows = snapshot.data ?? const [];
                    if (rows.isEmpty) {
                      return const EmptyView(
                        message: 'No certificates here.',
                        icon: Icons.workspace_premium_outlined,
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: rows.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = rows[i] as Map<String, dynamic>;
                        final approved = '${c['status']}' == 'Approved';
                        return ListTile(
                          leading: BrandImage(
                            approved ? BrandImages.seal : BrandImages.emblem,
                            height: 34,
                          ),
                          title: Text('${c['type']} · ${c['patientName']}'),
                          subtitle: Text('#${c['id']} · ${c['status']} · '
                              '${prettyDate('${c['certificateDate']}')}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final changed =
                            await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => CertificateDetailScreen(
                                    id: c['id'] as int),
                              ),
                            );
                            if (changed == true) _load(_status);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CertificateDetailScreen extends StatefulWidget {
  const CertificateDetailScreen({super.key, required this.id});
  final int id;

  @override
  State<CertificateDetailScreen> createState() =>
      _CertificateDetailScreenState();
}

class _CertificateDetailScreenState extends State<CertificateDetailScreen> {
  late final Future<Map<String, dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = ClinicApi.instance.certificate(widget.id);
  }

  Future<void> _act(String action, {String remarks = ''}) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final data = await _future;
      final certificate = data['certificate'] as Map<String, dynamic>;
      await ClinicApi.instance.certificateAction(
        widget.id,
        action,
        version: certificate['version'] as int, // optimistic lock
        remarks: remarks,
      );
      if (!mounted) return;
      navigator.pop(true);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnWithRemarks() async {
    final controller = TextEditingController();
    final remarks = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Return for revision'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Remarks (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(controller.text.trim()),
            child: const Text('Return'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remarks == null || remarks.isEmpty) return;
    await _act('return', remarks: remarks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: clinicAppBar('Certificate #${widget.id}'),
      body: ClinicBackground(
        veil: 0.97,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(error: snapshot.error!);
            }
            final c = snapshot.data!['certificate'] as Map<String, dynamic>;
            final history = (snapshot.data!['history'] as List?) ?? const [];
            final api = ClinicApi.instance;
            final approved = '${c['status']}' == 'Approved';
            final canSubmit = api.isNurse &&
                ['Draft', 'Returned for Revision'].contains('${c['status']}');
            final canReview =
                api.isDoctor && '${c['status']}' == 'Pending Approval';
            final theme = Theme.of(context);

            return Stack(
              children: [
                SealWatermark(
                  opacity: approved ? 0.10 : 0.04,
                  size: 300,
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Row(
                      children: [
                        BrandImage(
                          approved ? BrandImages.seal : BrandImages.emblem,
                          height: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            approved
                                ? 'Officially approved — University of La Salette'
                                : 'Draft / unofficial copy',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text('${c['type']}',
                        style: theme.textTheme.titleLarge),
                    Text('${c['patientName']} · ${c['patientId']}'),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text('${c['status']}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const Divider(height: 28),
                    for (final pair in <String, Object?>{
                      'Date': c['certificateDate'],
                      'Purpose': c['purpose'],
                      'Findings': c['findings'],
                      'Recommendations': c['recommendations'],
                      'Other details': c['otherDetails'],
                      'Remarks': c['remarks'],
                      'Created by': c['createdByName'],
                      'Approved by': c['approvedByName'],
                    }.entries)
                      if ('${pair.value ?? ''}'.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pair.key,
                                  style: theme.textTheme.labelMedium),
                              Text('${pair.value}'),
                            ],
                          ),
                        ),
                    const Divider(height: 28),
                    if (canSubmit)
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _act('submit'),
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Submit for approval'),
                      ),
                    if (canReview) ...[
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _act('approve'),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _returnWithRemarks,
                        icon: const Icon(Icons.undo),
                        label: const Text('Return for revision'),
                      ),
                    ],
                    const SizedBox(height: 22),
                    Text('History', style: theme.textTheme.titleMedium),
                    for (final raw in history)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.circle, size: 10),
                        title: Text('${(raw as Map)['action']}'),
                        subtitle: Text(
                          '${raw['actorName']} · ${raw['createdAt']}'
                              '${'${raw['remarks'] ?? ''}'.isEmpty ? '' : ' · ${raw['remarks']}'}',
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}