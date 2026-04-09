import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

Interceptor buildCookieInterceptor(CookieJar cookieJar) {
  return InterceptorsWrapper();
}
