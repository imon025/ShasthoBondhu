import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final query = 'napa';
  final res = await http.get(Uri.parse('https://medex.com.bd/brands?search=$query'));
  if (res.statusCode == 200) {
    final document = parser.parse(res.body);
    final aTags = document.querySelectorAll('a.hoverable-block');
    print('Found ${aTags.length} tags');
    String? matchedHref;
    String? matchedName;
    for (final tag in aTags) {
      final text = tag.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      print(text);
      if (text.toLowerCase().contains(query.toLowerCase())) {
        matchedHref = tag.attributes['href'];
        matchedName = text;
        break;
      }
    }
    if (matchedHref != null) {
      print('Fetching $matchedHref');
      final drugRes = await http.get(Uri.parse(matchedHref));
      final doc2 = parser.parse(drugRes.body);
      final packageDivs = doc2.querySelectorAll('.package-container');
      if (packageDivs.isEmpty) {
        print('No package-container found');
      }
      for (final p in packageDivs) {
        print(p.text.trim().replaceAll(RegExp(r'\s+'), ' '));
      }
    }
  } else {
    print('Error: ${res.statusCode}');
  }
}
