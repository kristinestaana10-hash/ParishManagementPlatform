import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/design/colors.dart';
import '../../../core/services/firebase_service.dart';

// Legacy offline context kept for reference; live answers now come from the
// secure Cloud Function and Firestore-backed prompt context.
// ignore: unused_element, constant_identifier_names
const String PARISH_CONTEXT =
    '''You are the AI assistant for Sto. Rosario Parish Church in Malipampang, San Ildefonso, Bulacan.
Always answer using the complete parish information, app features, and processes described below.

=== PARISH DETAILS ===
- Name: Sto. Rosario Parish Church (also known as "Apo Sayong" church)
- Location: CAGAYAN VALLEY RD., MALIPAMPANG, SAN ILDEFONSO, BULACAN 3010
- Phone: (044) 761-1693 or 0955-042-1977
- Email: sanjose.jaysantos@yahoo.com
- Parish Priest: Father Jose Santos (sanjose.jaysantos@yahoo.com)

=== MASS SCHEDULE ===
- Daily Mass: 6:30 AM (Monday-Saturday)
- Sunday Masses: 6:00 AM, 8:00 AM, 10:00 AM, 4:00 PM
- Special services: Holy Week celebrations, Town Thanksgiving (November 22nd), Fiesta (February 22nd)

=== SACRAMENTS OFFERED ===
The church offers 7 sacraments through the app:
1. Baptism (Binyag) - Christian initiation sacrament
2. Confirmation (Kumpil) - Strengthening faith
3. Wedding (Kasal) - Holy marriage
4. Funeral Mass (Misa para sa Yumao) - Prayer for the departed
5. House Blessing (Basbas ng Bahay) - Blessing of homes
6. Anointing of the Sick (Pagpapahid sa May Sakit) - Sacrament of healing
7. Mass Intentions (Intensyon ng Misa) - Offering mass intentions

=== PARISH HISTORY ===
Founded in 1919 by the people of Malipampang led by Ingkong Dano Villaceran.
- First chapel built in 1919 in the yard of Ingkong Narciso del Rosario (destroyed by storm)
- Second chapel built in 1919 in the yard of Impong Ining Violago (also destroyed by storm)
- Current church location established in the 1920s
- Image of Santisimo Rosario arrived in 1926 through efforts of Impong Ketang Nuñez Reyes
- First fiesta celebrated February 22, 1927
- Bell donated by Ingkong Mamerto Panganiban in 1926
- Town Thanksgiving established November 22nd annually
- Holy Week celebrations began under guidance of Ingkong Dano
- Deep devotion to Blessed Virgin Mary developed over time

=== APP FEATURES AND PROCESSES ===
The Sto. Rosario Parish Church mobile app provides:

1. **Home Screen**: Welcome banner with user greeting, 7 sacrament cards for booking
2. **Sacraments Booking**: Users can book any of the 7 sacraments through detailed forms
3. **Bookings Management**: View and manage all sacrament bookings in Bookings screen
4. **AI Chat Assistant**: Floating chatbot for questions about parish, services, and app usage
5. **Donations**: Multiple donation types (monetary, in-kind, other) with anonymous options
6. **Contact Information**: Complete parish contact details and service hours
7. **Parish History**: Detailed timeline of church founding and development
8. **Profile Management**: User account settings and logout functionality

=== USER ROLES AND PERMISSIONS ===
- **Guests**: Can browse app content, view services, access contact info, use AI chat, make donations
- **Registered Users**: All guest permissions plus ability to book sacraments and manage bookings
- **Authentication Required**: Sacrament bookings require user login/registration

=== BOOKING PROCESS ===
1. User selects sacrament from Home screen
2. Fills out detailed booking form with personal information
3. Provides required documents (birth certificates, marriage licenses, etc.)
4. Submits booking request
5. Booking appears in Bookings screen for tracking
6. Parish staff reviews and confirms bookings

=== DONATION PROCESS ===
- **Monetary Donations**: Specify amount, payment method
- **In-Kind Donations**: Describe items being donated
- **Other Donations**: Custom donation descriptions
- **Anonymous Option**: Choose to remain anonymous
- All donations processed through the Donations feature

=== CONTACT AND SUPPORT ===
- Phone: (044) 761-1693, 0955-042-1977
- Email: sanjose.jaysantos@yahoo.com
- Address: CAGAYAN VALLEY RD., MALIPAMPANG, SAN ILDEFONSO, BULACAN 3010
- Service Hours: Daily mass 6:30 AM, Sunday masses multiple times

=== LANGUAGE SUPPORT ===
- App supports both Tagalog and English
- AI assistant responds in the same language as the user's question
- All app content available in both languages

=== TECHNICAL INFORMATION ===
- Flutter mobile app with responsive design
- AI powered by Groq API
- Cross-platform support (iOS, Android, Web)

=== CRITICAL COMMUNICATION & LANGUAGE RULES ===
1. LANGUAGE DETECTION IS MANDATORY: You MUST detect the language of the user's specific query.
   - If the user asks in TAGALOG (e.g., "bakit", "ano", "paano", "saan"), your entire response MUST be logically constructed in fluid, natural TAGALOG.
   - If the user asks in ENGLISH (e.g., "why", "what", "how", "where"), your entire response MUST be in ENGLISH.
2. STRICT MATCHING: Do not mix languages unless absolutely necessary, and NEVER default to English if the user initiated in Tagalog. Only switch languages if the user's exact current prompt switches language.
3. Be respectful, highly empathetic, and reverent when discussing religious matters. Use clear, helpful language appropriate for church parishioners.
4. ABSOLUTE ACCURACY: Stay 100% strictly focused on the provided Sto. Rosario Parish Church information, app features, and parish operations below. 
   - Under NO circumstances should you invent external details, guess unknown parish schedules, or hallucinate non-existent sacrament rules. 
   - If something is missing from the context below, gracefully inform the user that you only have access to the provided mobile app system details.

Answer questions accurately about:
- Parish history and founding
- Mass schedules and service times
- Sacrament types and booking processes
- Contact information and location
- Donation procedures
- App features and navigation
- User permissions and authentication
- Parish events and celebrations''';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime createdAt;
  final bool isWelcome;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? createdAt,
    this.isWelcome = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'text': text,
    'isUser': isUser,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    text: map['text'] as String? ?? '',
    isUser: map['isUser'] as bool? ?? false,
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
  );
}

class AIChatScreen extends StatefulWidget {
  final bool isTagalog;

  const AIChatScreen({super.key, this.isTagalog = false});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  static const String _historyKey = 'parish_ai_chat_history_v1';
  static const String _welcomeText =
      "Hello! 👋 I'm the Parish AI Assistant.\n\nHow can I help you today?\n\nYou can ask me about:\n• Parish services\n• Sacrament requirements\n• Fees\n• Schedules\n• Bookings\n• Parish activities";

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isHistoryLoading = true;
  late bool _currentLanguageIsTagalog;

  @override
  void initState() {
    super.initState();
    _currentLanguageIsTagalog = widget.isTagalog;
    _messages.add(
      ChatMessage(text: _welcomeText, isUser: false, isWelcome: true),
    );
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final encoded = preferences.getString(_historyKey);
      if (encoded != null) {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          final history = decoded
              .whereType<Map>()
              .map(
                (entry) =>
                    ChatMessage.fromMap(Map<String, dynamic>.from(entry)),
              )
              .where((message) => message.text.isNotEmpty)
              .toList();
          if (history.isNotEmpty && mounted) {
            setState(() {
              _messages
                ..clear()
                ..addAll(history);
            });
          }
        }
      }
    } catch (error) {
      debugPrint('Could not restore local parish chat history: $error');
    } finally {
      if (mounted) {
        setState(() => _isHistoryLoading = false);
        _scrollToLatest();
      }
    }
  }

  Future<void> _saveChatHistory() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final history = _messages
          .where((message) => !message.isWelcome)
          .map((message) => message.toMap())
          .toList();
      if (history.isEmpty) {
        await preferences.remove(_historyKey);
      } else {
        await preferences.setString(_historyKey, jsonEncode(history));
      }
    } catch (error) {
      debugPrint('Could not save local parish chat history: $error');
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmClearChat() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear conversation?'),
        content: const Text(
          'This will permanently remove your chat history from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear Chat'),
          ),
        ],
      ),
    );
    if (shouldClear != true || !mounted) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_historyKey);
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(ChatMessage(text: _welcomeText, isUser: false, isWelcome: true));
    });
    _scrollToLatest();
  }

  bool _detectTagalogLanguage(String text) {
    // List of strong Tagalog indicators (avoid English words and substrings)
    final strongTagalogKeywords = [
      'bakit',
      'paano',
      'saan',
      'kailan',
      'sino',
      'alin',
      'salamat',
      'ngayon',
      'bukas',
      'kahapon',
      'misa',
      'binyag',
      'kumpil',
      'kasal',
      'basbas',
      'yumao',
      'intensyon',
      'sakramento',
      'parokya',
      'simbahan',
      'pari',
      'pero',
      'kundi',
      'dahil',
      'puwede',
      'kailangan',
      'gusto',
      'hinahanap',
      'tanong',
      'tulong',
      'matulong',
      'tulungan',
      'pwede',
      'siyempre',
      'talaga',
      'talagang',
      'okay',
      'okei',
      'okey',
      'okie',
      'ayos',
      'maganda',
      'ok lang',
      'walang problema',
      'malaki',
      'maliit',
      'magkano',
      'magkakano',
      'mahal',
      'mura',
      'libre',
      'bili',
      'bilhin',
      'bili ko',
      'binili',
      'bumili',
      'aling',
      'anung',
      'saan saan',
      'dito doon',
      'nanay',
      'tatay',
      'anak',
      'lola',
      'lolo',
      'ate',
      'kuya',
      'kaibigan',
      'bahay',
      'tahanan',
      'tumatay',
      'dies',
      'patay',
      'buhay',
      'matibay',
      'mahina',
      'malakas',
      'pag-ibig',
      'mahal ko',
      'nagmahal',
      'pagmamahal',
    ];

    final lowerText = text.toLowerCase();

    // Check for strong Tagalog keywords with word boundaries
    int strongMatches = 0;
    for (final keyword in strongTagalogKeywords) {
      if (_containsWholeWord(lowerText, keyword)) {
        strongMatches++;
      }
    }

    // Default to English if not clearly Tagalog
    return strongMatches >= 2;
  }

  bool _containsWholeWord(String text, String word) {
    // Check if word exists as a whole word (with word boundaries)
    final pattern = RegExp(
      r'\b' + RegExp.escape(word) + r'\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(text);
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isLoading || _isHistoryLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true));
      _isLoading = true;
    });
    _scrollToLatest();

    _messageController.clear();
    await _saveChatHistory();

    try {
      final detectedTagalog = _detectTagalogLanguage(messageText);
      if (detectedTagalog) {
        _currentLanguageIsTagalog = true;
      } else {
        _currentLanguageIsTagalog = false;
      }

      final List<Map<String, String>> conversationHistory = [];
      for (final message in _messages) {
        if (message.isWelcome) continue;
        conversationHistory.add({
          'role': message.isUser ? 'user' : 'assistant',
          'content': message.text,
        });
      }

      final aiReply = await FirebaseService.instance.askParishAssistant(
        message: messageText,
        history: conversationHistory,
      );

      final reply = ChatMessage(text: aiReply, isUser: false);
      if (mounted) {
        setState(() {
          _messages.add(reply);
        });
        _scrollToLatest();
      } else {
        _messages.add(reply);
      }
      await _saveChatHistory();
    } catch (error) {
      final errText = _currentLanguageIsTagalog
          ? 'Hindi makakonekta sa AI assistant ngayon. Subukan muli mamaya.'
          : 'The AI assistant is not available right now. Please try again later.';
      final reply = ChatMessage(text: errText, isUser: false);
      if (mounted) {
        setState(() {
          _messages.add(reply);
        });
        _scrollToLatest();
      } else {
        _messages.add(reply);
      }
      await _saveChatHistory();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<String> _getSuggestedPrompts() {
    return [
      'What are the baptism requirements?',
      'What are the parish fees?',
      "What are today's schedules?",
      'How can I book a sacrament?',
    ];
  }

  void _sendSuggestedMessage(String message) {
    setState(() {
      _messageController.text = message;
    });
    _sendMessage();
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  List<InlineSpan> _formatLine(String line, TextStyle baseStyle) {
    final normalizedLine = RegExp(r'^\s*[-*]\s+').hasMatch(line)
        ? line.replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ')
        : line;
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    var start = 0;
    for (final match in pattern.allMatches(normalizedLine)) {
      if (match.start > start) {
        spans.add(TextSpan(text: normalizedLine.substring(start, match.start)));
      }
      final text = match.group(1) ?? match.group(2) ?? '';
      spans.add(
        TextSpan(
          text: text,
          style: match.group(1) != null
              ? baseStyle.copyWith(fontWeight: FontWeight.w700)
              : baseStyle.copyWith(fontStyle: FontStyle.italic),
        ),
      );
      start = match.end;
    }
    if (start < normalizedLine.length) {
      spans.add(TextSpan(text: normalizedLine.substring(start)));
    }
    return spans;
  }

  Widget _buildFormattedMessage(String text, TextStyle style) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index++)
          if (lines[index].trim().isEmpty)
            const SizedBox(height: 7)
          else
            Padding(
              padding: EdgeInsets.only(
                bottom: index == lines.length - 1 ? 0 : 3,
              ),
              child: Text.rich(
                TextSpan(children: _formatLine(lines[index], style)),
                style: style,
              ),
            ),
      ],
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final foreground = message.isUser ? Colors.white : ParishColors.textBlue900;
    final baseStyle = TextStyle(color: foreground, fontSize: 14, height: 1.4);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            const CircleAvatar(
              radius: 15,
              backgroundColor: ParishColors.primaryBlue,
              child: Icon(
                Icons.chat_bubble,
                size: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: message.isUser
                      ? ParishColors.primaryBlue
                      : ParishColors.bgBlue50,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                    bottomRight: Radius.circular(message.isUser ? 4 : 16),
                  ),
                  border: message.isUser
                      ? null
                      : Border.all(color: ParishColors.borderBlue100),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormattedMessage(message.text, baseStyle),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            color: foreground.withValues(alpha: 0.72),
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: const BoxDecoration(
            color: ParishColors.primaryBlue,
            border: Border(
              bottom: BorderSide(color: ParishColors.borderBlue200),
            ),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.chat_bubble,
                  color: ParishColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parish AI Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Here to help',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Chat options',
                enabled: !_isHistoryLoading,
                iconColor: Colors.white,
                onSelected: (value) {
                  if (value == 'clear') _confirmClearChat();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline),
                        SizedBox(width: 10),
                        Text('Clear Chat'),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                tooltip: 'Close chat',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
        ),
        // Chat messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length + (_isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const Padding(
                  padding: EdgeInsets.only(left: 38, bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Parish AI Assistant is typing...',
                        style: TextStyle(
                          color: ParishColors.textGray600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }
              final message = _messages[index];
              return _buildMessage(message);
            },
          ),
        ),
        // Suggested prompts
        if (_messages.every((message) => message.isWelcome) &&
            !_isHistoryLoading)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _getSuggestedPrompts()
                      .map(
                        (prompt) => ActionChip(
                          label: Text(
                            prompt,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () => _sendSuggestedMessage(prompt),
                          backgroundColor: ParishColors.bgBlue50,
                          side: const BorderSide(
                            color: ParishColors.borderBlue100,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        // Input area
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: ParishColors.borderBlue100),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  enabled: !_isHistoryLoading,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Ask about parish services...',
                    hintStyle: const TextStyle(color: ParishColors.textGray600),
                    filled: true,
                    fillColor: ParishColors.bgGray50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: const BorderSide(
                        color: ParishColors.borderBlue100,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12.0),
              IconButton.filled(
                onPressed:
                    _messageController.text.trim().isEmpty ||
                        _isLoading ||
                        _isHistoryLoading
                    ? null
                    : _sendMessage,
                tooltip: 'Send message',
                style: IconButton.styleFrom(
                  backgroundColor: ParishColors.primaryBlue,
                  disabledBackgroundColor: ParishColors.borderBlue100,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
