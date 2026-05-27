const fs = require('fs');

const filePath = 'c:\\src\\parish_church\\sto_rosario_parish_church\\lib\\features\\ai_chat\\screens\\ai_chat_screen.dart';

const content = `import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/design/colors.dart';

const String GROQ_API_KEY = 'MOVED_TO_FIREBASE_SECRET';
const String GROQ_MODEL = 'llama3-8b-8192';

const String PARISH_CONTEXT = '''You are the AI assistant for Sto. Rosario Parish Church in Malipampang, San Ildefonso, Bulacan.
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

Language guidance:
- If the incoming message is in Tagalog, reply in Tagalog.
- If the incoming message is in English, reply in English.
- Use clear, helpful language appropriate for church members.
- Stay focused on Sto. Rosario Parish Church, the app's features, and parish operations.
- Do not invent unrelated external details.
- Be respectful and reverent when discussing religious matters.

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

  const AIChatScreen({super.key, this.isTagalog = true});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: widget.isTagalog
            ? 'Hello! Ako ang iyong Parish Assistant. Paano ako makakatulong sa iyo ngayon?'
            : 'Hello! I am your Parish Assistant. How can I help you today?',
        isUser: false,
      ),
    );
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
      final List<Map<String, String>> conversationHistory = [
        {'role': 'system', 'content': PARISH_CONTEXT},
      ];

      // Convert past local messages to the API format (ignoring initial welcome message)
      for (int i = 1; i < _messages.length; i++) {
        conversationHistory.add({
          'role': _messages[i].isUser ? 'user' : 'assistant',
          'content': _messages[i].text,
        });
      }

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $GROQ_API_KEY',
        },
        body: json.encode({
          'model': GROQ_MODEL,
          'messages': conversationHistory,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final aiReply = data['choices'][0]['message']['content'] as String? ??
            (widget.isTagalog
                ? 'Pasensya na, walang tugon mula sa server.'
                : 'Sorry, no reply from server.');

        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(text: aiReply, isUser: false));
          });
        }
      } else {
        final errMessage = widget.isTagalog
            ? 'May mali sa komunikasyon sa AI server. (code \${response.statusCode})\\nDetails: \${response.body}'
            : 'Communication error with AI server. (code \${response.statusCode})\\nDetails: \${response.body}';

        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(text: errMessage, isUser: false));
          });
        }
      }
    } catch (error) {
      final errText = widget.isTagalog
          ? 'Hindi makakonekta sa AI server. Subukan muli.\\nError: $error'
          : 'Could not connect to AI server. Please try again.\\nError: $error';
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
    if (widget.isTagalog) {
      return [
        'Ano ang mga sakramento?',
        'Paano mag-book ng binyag?',
        'Kailan ang misa?',
        'Saan ang simbahan?',
        'Paano mag-donate?',
      ];
    } else {
      return [
        'What are the sacraments?',
        'How to book baptism?',
        'When is mass?',
        'Where is the church?',
        'How to donate?',
      ];
    }
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isTagalog ? 'Mga mungkahi:' : 'Suggestions:',
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
                  children: _getSuggestedPrompts().map((prompt) => 
                    ActionChip(
                      label: Text(
                        prompt,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _sendSuggestedMessage(prompt),
                      backgroundColor: ParishColors.bgBlue50,
                      side: const BorderSide(color: ParishColors.borderBlue100),
                    )
                  ).toList(),
                ),
              ],
            ),
          ),
        // Input area
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: ParishColors.borderBlue100)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: widget.isTagalog
                        ? 'Magsulat ng inyong mensahe...'
                        : 'Type your message...',
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
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
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
\`;

fs.writeFileSync(filePath, content, 'utf8');
