import '../features/auth/application/session.dart';

String? sessionRedirect(SessionState session, String location) {
  final authPage = ['/login', '/registro', '/recuperar'].contains(location);
  final publicPage =
      location == '/inicio' ||
      location == '/catalogo' ||
      location == '/pedidos' ||
      location.startsWith('/producto/');
  switch (session.status) {
    case SessionStatus.loading:
    case SessionStatus.unavailable:
      return location == '/session' || publicPage ? null : '/session';
    case SessionStatus.signedOut:
      if (location == '/session') return '/login';
      return authPage || publicPage ? null : '/login';
    case SessionStatus.authenticated:
      final admin = session.profile!.isAdmin;
      final home = admin ? '/admin' : '/catalogo';
      if (authPage || location == '/session') return home;
      if (admin && !(location == '/perfil' || location.startsWith('/admin'))) {
        return home;
      }
      if (!admin && location.startsWith('/admin')) return home;
      return null;
  }
}
