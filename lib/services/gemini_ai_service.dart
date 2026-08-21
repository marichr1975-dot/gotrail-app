import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiTrailRequest {
  final String activity;
  final String place;
  final double? latitude;
  final double? longitude;
  final String distance;
  final String difficulty;
  final bool dog;
  final bool children;
  final bool forest;
  final bool rock;
  final bool loop;

  const AiTrailRequest({
    required this.activity,
    required this.place,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.difficulty,
    required this.dog,
    required this.children,
    required this.forest,
    required this.rock,
    required this.loop,
  });
}

class AiTrailSuggestion {
  final String title;
  final String summary;
  final String routeType;
  final String difficulty;
  final String distance;
  final List<String> reasons;
  final List<String> cautions;
  final String place;
  final double? latitude;
  final double? longitude;
  final bool dog;
  final bool children;
  final bool forest;
  final bool rock;
  final bool loop;

  const AiTrailSuggestion({
    required this.title,
    required this.summary,
    required this.routeType,
    required this.difficulty,
    required this.distance,
    required this.reasons,
    required this.cautions,
    this.place = '',
    this.latitude,
    this.longitude,
    this.dog = false,
    this.children = false,
    this.forest = false,
    this.rock = false,
    this.loop = true,
  });

  factory AiTrailSuggestion.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic value) => value is List
        ? value.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
        : const [];

    return AiTrailSuggestion(
      title: json['title']?.toString() ?? 'Proposta GoTr-AI',
      summary: json['summary']?.toString() ?? '',
      routeType: json['route_type']?.toString() ?? '',
      difficulty: json['difficulty']?.toString() ?? '',
      distance: json['distance']?.toString() ?? '',
      reasons: strings(json['reasons']),
      cautions: strings(json['cautions']),
    );
  }

  AiTrailSuggestion withRequest(AiTrailRequest r) => AiTrailSuggestion(
        title: title,
        summary: summary,
        routeType: routeType,
        difficulty: difficulty,
        distance: distance,
        reasons: reasons,
        cautions: cautions,
        place: r.place,
        latitude: r.latitude,
        longitude: r.longitude,
        dog: r.dog,
        children: r.children,
        forest: r.forest,
        rock: r.rock,
        loop: r.loop,
      );
}


class GeminiPlaceResult {
  final String label;
  final double latitude;
  final double longitude;
  final String region;
  final String province;

  const GeminiPlaceResult({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.region,
    required this.province,
  });
}

class GeminiAiService {
  GeminiAiService._();
  static final instance = GeminiAiService._();

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-3.5-flash-lite';

  bool get configured => _apiKey.trim().isNotEmpty;


  Future<List<GeminiPlaceResult>> resolvePlaces(
    String userText, {
    int limit = 5,
  }) async {
    final q = userText.trim();
    if (q.length < 2) return const [];
    if (!configured) {
      throw Exception(
        'Gemini non configurato. Avvia Flutter con --dart-define-from-file=gemini.json',
      );
    }

    final prompt = '''
Sei il motore di ricerca geografica di GoTr-AI.
L'utente sta cercando una località per pianificare un'escursione.

AREE ATTUALMENTE SUPPORTATE:
- Veneto: Belluno, Padova, Rovigo, Treviso, Venezia, Verona, Vicenza
- Trentino-Alto Adige / Südtirol: Trento, Bolzano
- Friuli-Venezia Giulia: Pordenone, Udine, Gorizia, Trieste

Testo digitato: "$q"

Interpreta errori di battitura, parole incomplete, frazioni, piccoli paesi,
località turistiche, rifugi, bivacchi, cime, passi, laghi e nomi italiani/tedeschi.
Se l'utente scrive un POI noto (es. un rifugio), identifica il POI reale e la sua provincia.
Restituisci fino a $limit località REALI ordinate dalla più probabile.

Ogni risultato deve avere:
- label leggibile
- province ESATTAMENTE tra: Belluno, Padova, Rovigo, Treviso, Venezia,
  Verona, Vicenza, Trento, Bolzano, Pordenone, Udine, Gorizia, Trieste
- region
- latitude
- longitude

Non inventare località o coordinate.
Se non trovi una corrispondenza ragionevole, restituisci results=[].
Rispondi esclusivamente nel JSON richiesto.
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'x-goog-api-key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.0,
              'maxOutputTokens': 700,
              'responseMimeType': 'application/json',
              'responseJsonSchema': {
                'type': 'object',
                'properties': {
                  'results': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'label': {'type': 'string'},
                        'region': {'type': 'string'},
                        'province': {'type': 'string'},
                        'latitude': {'type': 'number'},
                        'longitude': {'type': 'number'}
                      },
                      'required': [
                        'label',
                        'region',
                        'province',
                        'latitude',
                        'longitude'
                      ]
                    }
                  }
                },
                'required': ['results']
              }
            }
          }),
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
            'Gemini non ha risposto. Controlla la connessione Internet e riprova.',
          ),
        );

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is Map) {
          detail = (decoded['error'] as Map)['message']?.toString() ?? detail;
        }
      } catch (_) {}
      throw Exception('Gemini HTTP ${response.statusCode}: $detail');
    }

    final decoded = jsonDecode(response.body);
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return const [];
    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty || parts.first['text'] == null) {
      return const [];
    }

    final raw = jsonDecode(parts.first['text'].toString());
    if (raw is! Map || raw['results'] is! List) return const [];

    const allowedProvinces = {
      'Belluno', 'Padova', 'Rovigo', 'Treviso', 'Venezia', 'Verona',
      'Vicenza', 'Trento', 'Bolzano', 'Pordenone', 'Udine', 'Gorizia',
      'Trieste'
    };

    final results = <GeminiPlaceResult>[];
    for (final item in raw['results'] as List) {
      if (item is! Map) continue;
      final lat = (item['latitude'] as num?)?.toDouble();
      final lon = (item['longitude'] as num?)?.toDouble();
      final label = item['label']?.toString().trim() ?? '';
      final region = item['region']?.toString().trim() ?? '';
      final province = item['province']?.toString().trim() ?? '';
      if (lat == null || lon == null || label.isEmpty) continue;
      if (!allowedProvinces.contains(province)) continue;
      if (lat < 44.6 || lat > 47.2 || lon < 10.0 || lon > 14.2) continue;

      results.add(GeminiPlaceResult(
        label: label,
        latitude: lat,
        longitude: lon,
        region: region,
        province: province,
      ));
      if (results.length >= limit) break;
    }
    return results;
  }

  Future<GeminiPlaceResult?> resolvePlace(String userText) async {
    final results = await resolvePlaces(userText, limit: 1);
    return results.isEmpty ? null : results.first;
  }


  Future<AiTrailSuggestion> suggest(AiTrailRequest request) async {
    if (!configured) {
      throw Exception(
        'Gemini non configurato. Avvia Flutter con --dart-define=GEMINI_API_KEY=...',
      );
    }

    final position = request.latitude == null || request.longitude == null
        ? 'coordinate non disponibili'
        : '${request.latitude!.toStringAsFixed(6)}, ${request.longitude!.toStringAsFixed(6)}';

    final prompt = '''
Sei il motore AI di GoTr-AI, app per escursionisti non esperti.
Devi interpretare le preferenze dell'utente e proporre un PROFILO DI PERCORSO prudente.
Non inventare numeri di sentiero, rifugi, fontane, cascate o nomi di luoghi non presenti nei dati forniti.
Non affermare che un percorso reale esiste: la geometria verra verificata dalla mappa di GoTr-AI nel passo successivo.
Se ci sono bambini o cane, privilegia sicurezza, pendenze moderate, fondo semplice e possibilita di rientro.
Rispondi esclusivamente nel JSON richiesto.

DATI UTENTE:
- attivita: ${request.activity}
- zona: ${request.place}
- posizione: $position
- distanza desiderata: ${request.distance}
- difficolta: ${request.difficulty}
- cane: ${request.dog}
- bambini: ${request.children}
- bosco: ${request.forest}
- roccia: ${request.rock}
- anello: ${request.loop}
''';

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );

    final response = await http
        .post(
          uri,
          headers: {
            'x-goog-api-key': _apiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.1,
              'maxOutputTokens': 450,
              'responseMimeType': 'application/json',
              'responseJsonSchema': {
                'type': 'object',
                'properties': {
                  'title': {'type': 'string'},
                  'summary': {'type': 'string'},
                  'route_type': {'type': 'string'},
                  'difficulty': {'type': 'string'},
                  'distance': {'type': 'string'},
                  'reasons': {
                    'type': 'array',
                    'items': {'type': 'string'}
                  },
                  'cautions': {
                    'type': 'array',
                    'items': {'type': 'string'}
                  }
                },
                'required': [
                  'title',
                  'summary',
                  'route_type',
                  'difficulty',
                  'distance',
                  'reasons',
                  'cautions'
                ]
              }
            }
          }),
        )
        .timeout(
          const Duration(seconds: 60),
          onTimeout: () => throw TimeoutException(
            'Gemini non ha risposto entro 60 secondi. Controlla la connessione e riprova.',
          ),
        );

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['error'] is Map) {
          detail = (decoded['error'] as Map)['message']?.toString() ?? detail;
        }
      } catch (_) {}
      throw Exception('Gemini HTTP ${response.statusCode}: $detail');
    }

    final decoded = jsonDecode(response.body);
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw Exception('Gemini non ha restituito una proposta.');
    }
    final content = candidates.first['content'];
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List || parts.isEmpty || parts.first['text'] == null) {
      throw Exception('Risposta Gemini non leggibile.');
    }

    final raw = parts.first['text'].toString();
    final json = jsonDecode(raw);
    if (json is! Map) throw Exception('Risposta Gemini non valida.');

    return AiTrailSuggestion
        .fromJson(Map<String, dynamic>.from(json))
        .withRequest(request);
  }
}

