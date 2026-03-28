enum MethodType {
  get,
  post,
  put,
  delete,
  patch,
  head,
  options;

  String get apiValue {
    switch (this) {
      case MethodType.get:
        return 'GET';
      case MethodType.post:
        return 'POST';
      case MethodType.put:
        return 'PUT';
      case MethodType.delete:
        return 'DELETE';
      case MethodType.patch:
        return 'PATCH';
      case MethodType.head:
        return 'HEAD';
      case MethodType.options:
        return 'OPTIONS';
    }
  }
}
