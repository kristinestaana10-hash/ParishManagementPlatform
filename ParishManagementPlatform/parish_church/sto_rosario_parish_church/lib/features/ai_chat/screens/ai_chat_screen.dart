import 'package:flutter/material.dart';
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

  ChatMessage({required this.text, required this.isUser});
}

class AIChatScreen extends StatefulWidget {
  final bool isTagalog;

  const AIChatScreen({super.key, this.isTagalog = false});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  late bool _currentLanguageIsTagalog;

  @override
  void initState() {
    super.initState();
    _currentLanguageIsTagalog = widget.isTagalog;
    _messages.add(
      ChatMessage(
        text: 'Hello! I am your Parish Assistant. How can I help you today?',
        isUser: false,
      ),
    );
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
    if (messageText.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: messageText, isUser: true));
      _isLoading = true;
    });

    _messageController.clear();

    try {
      final detectedTagalog = _detectTagalogLanguage(messageText);
      if (detectedTagalog) {
        _currentLanguageIsTagalog = true;
      } else {
        _currentLanguageIsTagalog = false;
      }

      final List<Map<String, String>> conversationHistory = [];
      for (int i = 1; i < _messages.length; i++) {
        conversationHistory.add({
          'role': _messages[i].isUser ? 'user' : 'assistant',
          'content': _messages[i].text,
        });
      }

      final aiReply = await FirebaseService.instance.askParishAssistant(
        message: messageText,
        history: conversationHistory,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: aiReply, isUser: false));
        });
      }
    } catch (error) {
      final errText = _currentLanguageIsTagalog
          ? 'Hindi makakonekta sa AI assistant ngayon. Subukan muli mamaya.'
          : 'The AI assistant is not available right now. Please try again later.';
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: errText, isUser: false));
        });
      }
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
      'What sacraments and services can I book?',
      'How to book baptism?',
      'When is mass?',
      'Where is the church?',
      'How to donate?',
    ];
  }

  void _sendSuggestedMessage(String message) {
    setState(() {
      _messageController.text = message;
    });
    _sendMessage();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? ParishColors.primaryBlue
                        : ParishColors.bgBlue50,
                    borderRadius: BorderRadius.circular(16.0),
                    border: message.isUser
                        ? null
                        : Border.all(color: ParishColors.borderBlue100),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser
                          ? Colors.white
                          : ParishColors.textBlue900,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Suggested prompts
        if (_messages.length <= 1) // Only show when chat is mostly empty
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggestions:',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: ParishColors.textBlue900,
                  ),
                ),
                const SizedBox(height: 8),
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
          padding: const EdgeInsets.all(16.0),
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
                  decoration: InputDecoration(
                    hintText: 'Type your message... (or type Tagalog)',
                    hintStyle: const TextStyle(color: ParishColors.textGray600),
                    border: OutlineInputBorder(
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
              FloatingActionButton(
                onPressed: _sendMessage,
                backgroundColor: ParishColors.primaryBlue,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
