// cached_network_image: ^3.4.1
// cached_network_image_platform_interface: ^4.1.1
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:flutter/material.dart';

class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.url,
    this.token,
    this.headers,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.memCacheWidth,
    this.memCacheHeight,
    this.fadeInDuration = const Duration(milliseconds: 200),
    this.placeholder,
    this.errorWidget,
  }) : assert(
         token == null || headers == null,
         'Pass either `token` or `headers`, not both. '
         '`token` builds the Authorization headers for you.',
       );

  final String? url;

  /// Bearer auth token. When provided, the widget builds the
  /// `Authorization` / `Accept` headers automatically — pass this OR
  /// [headers], not both.
  final String? token;

  /// Explicit HTTP headers for authenticated images. Use [token] instead
  /// when you just need a standard `Bearer` auth header.
  final Map<String, String>? headers;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Rounds the corners. Ignored when [shape] is [BoxShape.circle].
  final BorderRadius? borderRadius;

  /// Use [BoxShape.circle] for avatars; clips the image to a circle.
  final BoxShape shape;

  /// Decode size hints to cap memory usage for large source images.
  final int? memCacheWidth;
  final int? memCacheHeight;

  final Duration fadeInDuration;

  /// Shown while loading. Defaults to a centered progress indicator.
  final WidgetBuilder? placeholder;

  /// Shown on failure or when [url] is empty. Defaults to a broken-image icon.
  final WidgetBuilder? errorWidget;

  /// Resolves the headers to send: explicit [headers] if given, otherwise
  /// headers built from [token], otherwise none.
  Map<String, String>? get _effectiveHeaders {
    if (headers != null) return headers;
    if (token != null && token!.isNotEmpty) {
      return {
        'Authorization': 'Bearer $token',
        'Accept': 'image/png,image/jpeg,image/*',
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;

    final Widget child = hasUrl
        ? CachedNetworkImage(
            imageUrl: url!,
            httpHeaders: _effectiveHeaders,
            // On web the default renders via an HTML <img> element, which
            // ignores httpHeaders and breaks authenticated endpoints
            // ("EncodingError: source image cannot be decoded"). HttpGet
            // fetches the bytes with the headers and decodes them instead.
            imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
            fit: fit,
            width: width,
            height: height,
            memCacheWidth: memCacheWidth,
            memCacheHeight: memCacheHeight,
            fadeInDuration: fadeInDuration,
            placeholder: (context, _) => _buildPlaceholder(context),
            errorWidget: (context, failedUrl, error) {
              debugPrint('AppCachedImage failed: $failedUrl -> $error');
              return _buildError(context);
            },
          )
        : SizedBox(width: width, height: height, child: _buildError(context));

    return _applyShape(child);
  }

  Widget _applyShape(Widget child) {
    if (shape == BoxShape.circle) {
      return ClipOval(child: child);
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildPlaceholder(BuildContext context) {
    if (placeholder != null) return placeholder!(context);
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    if (errorWidget != null) return errorWidget!(context);
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
