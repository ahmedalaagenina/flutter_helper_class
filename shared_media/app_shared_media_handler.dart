import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:idara_esign/config/routes/route_names.dart';
import 'package:idara_esign/core/services/shared_media/shared_media_service.dart';
import 'package:idara_esign/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:idara_esign/features/document/presentation/pages/image_to_document_page.dart';
import 'package:idara_esign/generated/l10n.dart';

/// Handles the app-specific routing and authentication checks for shared files.
///
/// While `SharedMediaService` is fully reusable across any app, this class
/// contains the logic specific to iDara eSign (checking `AuthBloc`, navigating
/// to specific `Routes`, and showing localized dialogs). 
/// Extracting this keeps `app.dart` clean.
class AppSharedMediaHandler {
  AppSharedMediaHandler({
    required this.sharedFileService,
    required this.authBloc,
    required this.navigatorKey,
  });

  final SharedMediaService sharedFileService;
  final AuthBloc authBloc;
  final GlobalKey<NavigatorState> navigatorKey;

  StreamSubscription<List<SharedFile>>? _filesSub;
  StreamSubscription<AuthState>? _authSub;

  /// Starts listening to file shares and authentication changes.
  void init() {
    _filesSub = sharedFileService.onFilesReceived.listen(_onFilesReceived);
    _authSub = authBloc.stream
        .distinct((a, b) => a.authStatus == b.authStatus)
        .listen(_onAuthChanged);
  }

  /// Cancels subscriptions to prevent memory leaks.
  void dispose() {
    _filesSub?.cancel();
    _authSub?.cancel();
  }

  bool get _isAuthenticated =>
      authBloc.state.authStatus == AuthStatus.authenticated &&
      authBloc.state.user?.isGuest != true;

  void _onFilesReceived(List<SharedFile> files) {
    if (_isAuthenticated) {
      _handleSharedFiles(files);
      sharedFileService.consumePendingFiles();
    }
    // If not authenticated, files stay as pendingFiles.
    // _onAuthChanged will pick them up after login.
  }

  void _onAuthChanged(AuthState state) {
    if (state.authStatus == AuthStatus.authenticated &&
        state.user?.isGuest != true) {
      final pending = sharedFileService.pendingFiles;
      if (pending.isNotEmpty) {
        // Small delay to let the router settle after auth redirect.
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleSharedFiles(pending);
          sharedFileService.consumePendingFiles();
        });
      }
    }
  }

  /// Routes the shared files to the correct flow based on their type.
  void _handleSharedFiles(List<SharedFile> files) {
    final pdfs = files.where((f) => f.type == SharedFileType.pdf).toList();
    final images = files.where((f) => f.type == SharedFileType.image).toList();

    if (pdfs.isNotEmpty) {
      _navigateToCreateWithFile(pdfs.first);
    } else if (images.isNotEmpty) {
      _navigateToImagesFlow(images);
    } else {
      // Unsupported file type — the app opened successfully but we can't
      // process this file. Show a friendly dialog so the user knows.
      _showUnsupportedFileDialog();
    }
  }

  void _navigateToCreateWithFile(SharedFile file) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final platformFile = PlatformFile(
      path: file.path,
      name: file.name,
      size: file.size,
    );
    context.pushNamed(
      Routes.userDocumentCreate,
      extra: {'initialFile': platformFile},
    );
  }

  Future<void> _navigateToImagesFlow(List<SharedFile> files) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final imagePaths = files.map((f) => f.path).toList();
    if (imagePaths.isEmpty) return;

    // Push ImageToDocumentPage and await the result PDF.
    final resultFile = await Navigator.of(context).push<PlatformFile>(
      MaterialPageRoute(
        builder: (_) => ImageToDocumentPage(initialImagePaths: imagePaths),
      ),
    );
    if (resultFile == null) return;

    // Schedule the navigation to create-doc on the next frame so we don't
    // hold a stale BuildContext across the async gap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      ctx.pushNamed(
        Routes.userDocumentCreate,
        extra: {'initialFile': resultFile},
      );
    });
  }

  void _showUnsupportedFileDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    final s = S.of(context);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.unsupportedFile),
        content: Text(s.unsupportedFileHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.ok),
          ),
        ],
      ),
    );
  }
}
