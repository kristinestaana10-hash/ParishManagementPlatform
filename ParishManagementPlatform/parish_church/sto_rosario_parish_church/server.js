require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 5000;
const GROQ_API_KEY = process.env.GROQ_API_KEY;
const GROQ_MODEL = process.env.GROQ_MODEL || 'llama3-8b-8192';

// Middleware
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  optionsSuccessStatus: 200
}));
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', message: 'Chatbot server is running' });
});

// Chat endpoint
app.post('/chat', async (req, res) => {
  try {
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({ error: 'Message is required' });
    }

    // Handle common questions directly for accuracy (before checking API key)
    const lowerMessage = message.toLowerCase();
    if (lowerMessage.includes('address') || lowerMessage.includes('location') || lowerMessage.includes('where')) {
      res.json({
        success: true,
        message: message,
        reply: 'The church is located at CAGAYAN VALLEY RD., MALIPAMPANG, SAN ILDEFONSO, BULACAN 3010.',
      });
      return;
    } else if (lowerMessage.includes('phone') || lowerMessage.includes('contact') || lowerMessage.includes('number')) {
      res.json({
        success: true,
        message: message,
        reply: 'You can contact the church at (044) 761-1693 or 0955-042-1977.',
      });
      return;
    } else if (lowerMessage.includes('email')) {
      res.json({
        success: true,
        message: message,
        reply: 'The church email is sanjose.jaysantos@yahoo.com (Father Jose Santos).',
      });
      return;
    } else if (lowerMessage.includes('mass') && (lowerMessage.includes('time') || lowerMessage.includes('schedule'))) {
      res.json({
        success: true,
        message: message,
        reply: 'Daily Mass is at 6:30 AM (Monday-Saturday). Sunday Masses are at 6:00 AM, 8:00 AM, 10:00 AM, and 4:00 PM.',
      });
      return;
    } else if (lowerMessage.includes('sacrament')) {
      res.json({
        success: true,
        message: message,
        reply: 'The church offers these sacraments: Baptism, Confirmation, Wedding, Funeral Mass, House Blessing, Anointing of the Sick, and Mass Intentions. You can book appointments through the app by selecting a sacrament from the Home screen.',
      });
      return;
    } else if (lowerMessage.includes('history') || lowerMessage.includes('founded') || lowerMessage.includes('started')) {
      res.json({
        success: true,
        message: message,
        reply: 'Sto. Rosario Parish Church was founded in 1919 by the people of Malipampang led by Ingkong Dano Villaceran. The first chapels were destroyed by storms, and the current location was established in the 1920s. The image of Santisimo Rosario arrived in 1926.',
      });
      return;
    } else if (lowerMessage.includes('donation') || lowerMessage.includes('donate')) {
      res.json({
        success: true,
        message: message,
        reply: 'You can make donations through the Donations feature in the app. We accept monetary donations, in-kind donations, and other contributions. You can choose to remain anonymous.',
      });
      return;
    } else if (lowerMessage.includes('booking') || lowerMessage.includes('book') || lowerMessage.includes('appointment')) {
      res.json({
        success: true,
        message: message,
        reply: 'To book a sacrament, go to the Home screen and tap on the sacrament you need (Baptism, Confirmation, Wedding, etc.). Fill out the booking form with your details and required documents. Registered users can manage their bookings in the Bookings screen.',
      });
      return;
    } else if (lowerMessage.includes('priest') || lowerMessage.includes('father') || lowerMessage.includes('pastor')) {
      res.json({
        success: true,
        message: message,
        reply: 'The parish priest is Father Jose Santos. You can contact him at sanjose.jaysantos@yahoo.com or call the church office.',
      });
      return;
    }

    // For other questions, use AI with comprehensive parish and app context (if API key available)
    if (!GROQ_API_KEY || GROQ_API_KEY.trim() === '') {
      // Use comprehensive fallback for all other questions when API key is not available
      const fallbackReplies = [
        'Hello! I am the Parish Assistant for Sto. Rosario Parish Church. How can I help you today?',
        'Welcome to our parish app! I can help you with information about masses, sacraments, bookings, and church services.',
        'I can assist you with questions about our church history, mass schedules, sacrament bookings, donations, and contact information.',
        'Feel free to ask about our 7 sacraments: Baptism, Confirmation, Wedding, Funeral Mass, House Blessing, Anointing of the Sick, and Mass Intentions.',
        'Our church is located at CAGAYAN VALLEY RD., MALIPAMPANG, SAN ILDEFONSO, BULACAN 3010. Daily mass at 6:30 AM, Sunday masses at 6AM, 8AM, 10AM, and 4PM.',
        'You can contact us at (044) 761-1693 or 0955-042-1977, or email sanjose.jaysantos@yahoo.com.',
      ];
      const randomReply = fallbackReplies[Math.floor(Math.random() * fallbackReplies.length)];

      return res.json({
        success: true,
        message: message,
        reply: randomReply,
        note: 'Using comprehensive fallback mode with parish information',
      });
    }

    const context = `You are the AI assistant for Sto. Rosario Parish Church in Malipampang, San Ildefonso, Bulacan.
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
- Backend server running on port 5000
- AI powered by Groq API (when available)
- Fallback responses when AI service unavailable
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
- Parish events and celebrations`;

    // Call Groq API
    const response = await axios.post(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        model: GROQ_MODEL,
        messages: [
          {
            role: 'system',
            content: context,
          },
          {
            role: 'user',
            content: `Language: ${req.body.language || 'english'}\nQuestion: ${message}`,
          },
        ],
        stream: false,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${GROQ_API_KEY}`,
        },
      }
    );

    const aiResponse = response.data.choices[0].message.content;

    res.json({
      success: true,
      message: message,
      reply: aiResponse,
    });
  } catch (error) {
    console.error('Error calling Groq API:', error.response?.data || error.message);

    if (error.response?.status === 401) {
      return res.status(401).json({ error: 'Unauthorized: Invalid API key' });
    }

    if (error.response?.status === 429) {
      return res.status(429).json({ error: 'Rate limit exceeded' });
    }

    res.status(500).json({
      error: 'Failed to get response from AI',
      details: error.message,
    });
  }
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🤖 Chatbot server is running on port ${PORT}`);
  console.log(`📝 POST /chat - Send a message to the chatbot`);
  console.log(`🏥 GET /health - Check server status`);
});
