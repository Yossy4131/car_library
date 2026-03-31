import 'dart:convert';
import 'package:http/http.dart' as http;

/// NHTSA vPIC API との通信を担当するサービスクラス
/// https://vpic.nhtsa.dot.gov/api/
class NHTSAService {
  static const _baseUrl = 'https://vpic.nhtsa.dot.gov/api/vehicles';

  final http.Client _client;

  NHTSAService({http.Client? client}) : _client = client ?? http.Client();

  /// 全メーカー一覧を取得
  Future<List<String>> getAllMakes() async {
    final uri = Uri.parse('$_baseUrl/GetAllMakes?format=json');
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('メーカー一覧の取得に失敗しました (${response.statusCode})');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['Results'] as List<dynamic>;

    return results
        .map((e) => (e['Make_Name'] as String).trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  /// 指定メーカーのモデル一覧を取得
  Future<List<String>> getModelsForMake(String make) async {
    final encodedMake = Uri.encodeComponent(make);
    final uri = Uri.parse(
      '$_baseUrl/GetModelsForMake/$encodedMake?format=json',
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('モデル一覧の取得に失敗しました (${response.statusCode})');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['Results'] as List<dynamic>;

    return results
        .map((e) => (e['Model_Name'] as String).trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}
