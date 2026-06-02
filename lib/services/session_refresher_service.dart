import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as hp;
import 'package:html/dom.dart' as dom;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Headless background portal authenticator and session cookie refresher.
class SessionRefresherService {
  /// Solves the math captcha (e.g. "5 + 3" or "10 - 2") found inside the page HTML.
  static String? _solveMathCaptcha(String html) {
    // 1. Check for standard numeric operators: e.g. 5 + 3, 10 - 2, 4 * 3
    final match = RegExp(r'(\d+)\s*([\+\-\*])\s*(\d+)').firstMatch(html);
    if (match != null) {
      final num1 = int.parse(match.group(1)!);
      final op = match.group(2)!;
      final num2 = int.parse(match.group(3)!);
      if (op == '+') return (num1 + num2).toString();
      if (op == '-') return (num1 - num2).toString();
      if (op == '*') return (num1 * num2).toString();
    }

    // 2. Check for textual operators: e.g. 5 plus 3, 10 minus 2, 4 times 3
    final textMatch = RegExp(
      r'(\d+)\s*(plus|minus|times)\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(html);
    if (textMatch != null) {
      final num1 = int.parse(textMatch.group(1)!);
      final op = textMatch.group(2)!.toLowerCase();
      final num2 = int.parse(textMatch.group(3)!);
      if (op == 'plus') return (num1 + num2).toString();
      if (op == 'minus') return (num1 - num2).toString();
      if (op == 'times') return (num1 * num2).toString();
    }

    return null;
  }

  /// Refreshes/warms the portal session by logging in headlessly in the background.
  /// If successful, persists the cookies and warms the WebViewCookieManager.
  static Future<bool> warmSession(String host, String sessionScope) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Fetch saved credentials from SharedPreferences
    final uKey = 'iris_login_${sessionScope}_${host.toLowerCase()}_u';
    final pKey = 'iris_login_${sessionScope}_${host.toLowerCase()}_p';

    final encU = prefs.getString(uKey);
    final encP = prefs.getString(pKey);

    if (encU == null || encP == null || encU.isEmpty || encP.isEmpty) {
      print('❄️ Session Refresher: No credentials stored for $host ($sessionScope). Skipping.');
      return false;
    }

    final username = utf8.decode(base64Decode(encU));
    final password = utf8.decode(base64Decode(encP));

    print('📡 Session Refresher: Warming session for $host ($sessionScope)...');

    try {
      final baseUrl = 'https://$host';
      final loginUrl = '$baseUrl/Login/Index';

      final userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      // 2. Fetch the login index page to obtain initial session cookies and anti-forgery tokens
      final getResponse = await http.get(Uri.parse(loginUrl), headers: {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode != 200) {
        print('❌ Session Refresher: Failed to load login page. Status: ${getResponse.statusCode}');
        return false;
      }

      // 3. Extract ASP.NET_SessionId cookie
      final setCookie = getResponse.headers['set-cookie'];
      if (setCookie == null || setCookie.isEmpty) {
        print('❌ Session Refresher: No cookies returned in initial response.');
        return false;
      }

      // Parse cookie string (keep only relevant key-value pairs)
      final getCookiesList = setCookie.split(',').map((c) => c.split(';').first.trim()).toList();
      final getCookieHeader = getCookiesList.join('; ');

      // 4. Parse inputs dynamically using html parser
      final document = hp.parse(getResponse.body);
      final inputs = document.querySelectorAll('input');

      dom.Element? passwordField;
      dom.Element? usernameField;
      dom.Element? captchaField;
      dom.Element? csrfField;

      // Find password field
      for (final input in inputs) {
        final type = input.attributes['type']?.toLowerCase() ?? '';
        if (type == 'password') {
          passwordField = input;
          break;
        }
      }

      bool isCaptcha(dom.Element el) {
        final meta = [
          el.attributes['id'],
          el.attributes['name'],
          el.attributes['placeholder'],
          el.attributes['class']
        ].whereType<String>().join(' ').toLowerCase();
        return RegExp(r'captcha|code|verif|validate|security', caseSensitive: false).hasMatch(meta);
      }

      int scoreField(dom.Element el) {
        final type = el.attributes['type']?.toLowerCase() ?? '';
        if (type == 'hidden' || type == 'password' || type == 'submit' || type == 'button' || type == 'checkbox' || type == 'radio') {
          return -100;
        }
        final meta = [
          el.attributes['name'],
          el.attributes['id'],
          el.attributes['placeholder'],
          el.attributes['autocomplete'],
          el.attributes['type']
        ].whereType<String>().join(' ').toLowerCase();
        
        int score = 0;
        if (RegExp(r'email|user|username|login|roll|reg|id|student|account', caseSensitive: false).hasMatch(meta)) {
          score += 5;
        }
        if (RegExp(r'search|query|find|filter', caseSensitive: false).hasMatch(meta)) {
          score -= 5;
        }
        if (type == 'text' || type == 'email' || type == 'tel' || type == 'number') {
          score += 1;
        }
        if (isCaptcha(el)) {
          score -= 20;
        }
        return score;
      }

      final candidates = inputs.where((el) => el != passwordField).toList();
      candidates.sort((a, b) => scoreField(b).compareTo(scoreField(a)));
      if (candidates.isNotEmpty && scoreField(candidates.first) > -50) {
        usernameField = candidates.first;
      }

      for (final input in inputs) {
        final type = input.attributes['type']?.toLowerCase() ?? '';
        if (type != 'text' && type != 'number') continue;
        if (isCaptcha(input)) {
          captchaField = input;
          break;
        }
      }

      for (final input in inputs) {
        final name = input.attributes['name'] ?? '';
        if (name == '__RequestVerificationToken') {
          csrfField = input;
          break;
        }
      }

      final captchaSolution = _solveMathCaptcha(getResponse.body);
      if (captchaSolution == null) {
        print('❌ Session Refresher: Could not solve math CAPTCHA from HTML.');
        return false;
      }
      print('✓ Session Refresher: Solved Math CAPTCHA: $captchaSolution');

      // 5. Send POST login request
      final postHeaders = {
        'User-Agent': userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Content-Type': 'application/x-www-form-urlencoded',
        'Cookie': getCookieHeader,
        'Referer': loginUrl,
      };

      final postBody = {
        usernameField?.attributes['name'] ?? 'RegistrationId': username,
        passwordField?.attributes['name'] ?? 'Password': password,
      };
      if (captchaField != null) {
        postBody[captchaField.attributes['name'] ?? 'CaptchaInput'] = captchaSolution;
      }
      if (csrfField != null) {
        postBody[csrfField.attributes['name'] ?? '__RequestVerificationToken'] = csrfField.attributes['value'] ?? '';
      }

      final postResponse = await http.post(
        Uri.parse(loginUrl),
        headers: postHeaders,
        body: postBody,
      ).timeout(const Duration(seconds: 10));

      final postSetCookie = postResponse.headers['set-cookie'];
      
      final List<String> finalCookiesList = [];
      finalCookiesList.addAll(getCookiesList);
      if (postSetCookie != null && postSetCookie.isNotEmpty) {
        finalCookiesList.addAll(
          postSetCookie.split(',').map((c) => c.split(';').first.trim())
        );
      }

      final cookieMap = <String, String>{};
      for (final cookie in finalCookiesList) {
        final parts = cookie.split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
      final cookieString = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');

      final success = postResponse.statusCode == 302 ||
          postResponse.statusCode == 301 ||
          postResponse.body.contains('/Logout') ||
          postResponse.body.contains('Dashboard');

      if (!success) {
        print('❌ Session Refresher: Login failed (incorrect credentials or expired CAPTCHA).');
        return false;
      }

      // 6. Save authenticated cookies to SharedPreferences
      final cookieKey = 'iris_session_${sessionScope}_${host.toLowerCase()}_cookies';
      await prefs.setString(cookieKey, cookieString);

      if (sessionScope == 'student') {
        await prefs.setString('iris_session_student_${host.toLowerCase()}_cookies', cookieString);
      }

      // 7. Inject cookies directly into webview_flutter WebViewCookieManager
      final cookieManager = WebViewCookieManager();
      for (final entry in cookieMap.entries) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: entry.key,
            value: entry.value,
            domain: host,
            path: '/',
          ),
        );
      }

      print('🔥 Session Refresher: Session successfully warmed for $host! Cookies injected.');
      return true;
    } catch (e) {
      print('❌ Session Refresher: Error warming session for $host: $e');
      return false;
    }
  }
}
