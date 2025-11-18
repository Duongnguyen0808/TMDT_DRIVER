// Cấu hình Vietmap cho ứng dụng shipper.
// Nếu có API key thật hãy thay vào biến dưới đây.
const String vietmapApiKey =
    "2b80a3786959d7a6f08f3d3a9ec4f35d471f93ea4fe39f40"; // Demo key

bool hasRealVietmapKey([String? apiKey]) {
  final key = (apiKey ?? vietmapApiKey).trim();
  return key.isNotEmpty && key.length > 20;
}

/// Trả về style URL: dùng Vietmap nếu key hợp lệ, ngược lại dùng MapLibre demo.
String vietmapStyleUrl([String? apiKey]) {
  final key = (apiKey ?? vietmapApiKey).trim();
  if (key.isNotEmpty && key.length > 20) {
    return "https://maps.vietmap.vn/maps/styles/tm/style.json?apikey=$key";
  }
  return "https://demotiles.maplibre.org/style.json"; // fallback
}
