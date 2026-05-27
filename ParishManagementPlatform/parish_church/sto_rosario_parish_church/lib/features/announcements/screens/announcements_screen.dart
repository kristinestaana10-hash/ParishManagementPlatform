import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/gradients.dart';

class AnnouncementsScreen extends StatelessWidget {
  final bool isTagalog;

  const AnnouncementsScreen({super.key, this.isTagalog = true});

  String _t(String tagalog, String english) => isTagalog ? tagalog : english;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1024;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.5),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: ParishGradients.blueHeroGradient,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color.fromRGBO(255, 255, 255, 0.2),
                        border: Border.all(
                          color: ParishColors.primaryGold,
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.campaign,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('Mga Anunsyo', 'Announcements'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t('Mga balita at paalala mula sa parokya',
                          'News and reminders from the parish'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 15,
                        color: ParishColors.blue200,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        _t('Hindi ma-load ang mga anunsyo.',
                            'Unable to load announcements.'),
                        style: const TextStyle(color: ParishColors.textGray600),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        _t('Wala pang anunsyo sa ngayon.',
                            'No announcements yet.'),
                        style: const TextStyle(color: ParishColors.textGray600),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final title = (data['title'] ?? '').toString().trim();
                      final body = (data['body'] ?? data['content'] ?? '')
                          .toString()
                          .trim();
                      String imageUrl = '';
                      final directImage = data['imageUrl'] ??
                          data['imageURL'] ??
                          data['image'] ??
                          data['photoUrl'] ??
                          data['photoURL'];
                      if (directImage is String) {
                        imageUrl = directImage.trim();
                      } else {
                        final images = data['images'];
                        if (images is List && images.isNotEmpty) {
                          final first = images.first;
                          if (first is String) {
                            imageUrl = first.trim();
                          } else if (first is Map) {
                            final url = first['url'] ?? first['imageUrl'];
                            if (url is String) {
                              imageUrl = url.trim();
                            }
                          }
                        }
                      }

                      final createdAt = data['createdAt'];
                      DateTime? created;
                      if (createdAt is Timestamp) {
                        created = createdAt.toDate();
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: ParishColors.borderBlue100,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: ParishColors.bgBlue50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: ParishColors.borderBlue100,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.announcement_outlined,
                                      color: ParishColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title.isEmpty
                                              ? _t('Anunsyo', 'Announcement')
                                              : title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: ParishColors.textBlue900,
                                          ),
                                        ),
                                        if (created != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            created.toLocal().toString(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: ParishColors.textGray600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (imageUrl.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: ParishColors.bgBlue50,
                                          alignment: Alignment.center,
                                          child: const Icon(
                                            Icons.broken_image_outlined,
                                            color: ParishColors.textGray600,
                                            size: 28,
                                          ),
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) {
                                          return child;
                                        }
                                        return Container(
                                          color: ParishColors.bgBlue50,
                                          alignment: Alignment.center,
                                          child: const CircularProgressIndicator(),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                              if (body.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  body,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: ParishColors.textBlue900,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
