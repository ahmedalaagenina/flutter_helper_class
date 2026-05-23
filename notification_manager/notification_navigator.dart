import 'package:go_router/go_router.dart';
import 'package:idara_esign/config/routes/app_router.dart';
import 'package:idara_esign/config/routes/route_names.dart';
import 'package:idara_esign/core/responsive/responsive.dart';
import 'package:idara_esign/core/services/document_service.dart';
import 'package:idara_esign/core/services/logger_service.dart';
import 'package:idara_esign/di/injection_container.dart';
import 'package:idara_esign/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:idara_esign/features/document/domain/usecases/get_document.dart';

/// Routes a notification payload to the matching in-app destination.
///
/// Priority:
/// 1. `document_id` → fetch the document, then run [DocumentService.getAction]
///    so the user lands on the correct screen (sign / approve / view).
/// 2. `transaction_id` → open the transactions list.
class NotificationNavigator {
  NotificationNavigator._();

  static Future<void> handle(Map<String, dynamic> data) async {
    final documentId = _readString(data, 'document_id');
    final transactionId = _readString(data, 'transaction_id');
    if (transactionId != null) {
      _openTransactions();
      return;
    }
    if (documentId != null) {
      await _openDocument(documentId);
      return;
    }

    AppLog.d(
      '[NotificationNavigator] no document_id or transaction_id in: $data',
    );
  }

  static Future<void> _openDocument(String documentId) async {
    final authBloc = getIt<AuthBloc>();
    final authState = authBloc.state;
    if (authState.authStatus != AuthStatus.authenticated) {
      AppLog.d('[NotificationNavigator] not authenticated — skipping');
      return;
    }

    final getDoc = getIt<GetDocumentUseCase>();
    final result = await getDoc(
      GetDocumentParams(documentId: documentId, isGuest: false),
    );

    await result.fold(
      (failure) async {
        AppLog.e('[NotificationNavigator] failed to load document: $failure');
      },
      (document) async {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        final action = getIt<DocumentService>().getAction(
          document: document,
          userId: authState.user?.id ?? 0,
        );
        await action.execute(context, isInsideApp: false);
      },
    );
  }

  static void _openTransactions() {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final route = context.isMobileLayout
        ? Routes.transactionsMobile
        : Routes.transactions;
    context.go(route);
  }

  static String? _readString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return null;
    return str;
  }
}
