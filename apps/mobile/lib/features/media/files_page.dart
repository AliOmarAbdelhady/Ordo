import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/models.dart';
import '../../shared/widgets.dart';

class FilesPage extends ConsumerWidget {
  final String? groupId;
  const FilesPage({super.key, this.groupId});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    final f = result.files.single;
    try {
      await ref.read(apiClientProvider).uploadMedia(f.path!, f.name, groupId: groupId);
      ref.invalidate(mediaProvider(groupId));
      if (context.mounted) toast(context, 'Uploaded');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mediaProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Files')),
      floatingActionButton: FloatingActionButton(onPressed: () => _pick(context, ref), child: const Icon(Icons.upload_file)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => OEmptyState(icon: Icons.error_outline, title: 'Couldn’t load', subtitle: '$e', action: TextButton(onPressed: () => ref.invalidate(mediaProvider(groupId)), child: const Text('Retry'))),
        data: (files) {
          if (files.isEmpty) return const OEmptyState(icon: Icons.folder_outlined, title: 'No files yet', subtitle: 'Upload an image, PDF or document.');
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mediaProvider(groupId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(OrdoSpacing.lg),
              itemCount: files.length,
              itemBuilder: (_, i) => _fileTile(context, ref, files[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _fileTile(BuildContext context, WidgetRef ref, MediaFile f) {
    final isImg = f.isImage;
    return Padding(
      padding: const EdgeInsets.only(bottom: OrdoSpacing.sm),
      child: OCard(
        padding: const EdgeInsets.symmetric(horizontal: OrdoSpacing.md, vertical: OrdoSpacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(OrdoRadius.md)),
              child: Icon(isImg ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: OrdoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${f.uploaderName} · ${_size(f.sizeBytes)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondary)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () async {
                final ok = await confirm(context, title: 'Delete file?', danger: true);
                if (!ok) return;
                try {
                  await ref.read(apiClientProvider).deleteMedia(f.id);
                  ref.invalidate(mediaProvider(groupId));
                } on ApiException catch (e) {
                  if (context.mounted) toast(context, e.message, error: true);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
