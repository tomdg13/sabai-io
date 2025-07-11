

class AppConfig {

  static const String baseUrl = 'http://209.97.172.105:3000';

  static Uri api(String endpoint) {
    return Uri.parse('$baseUrl$endpoint');
  }
  static String photoUrl(String photoName) {
    return '$baseUrl/photos/$photoName';
  }
}
