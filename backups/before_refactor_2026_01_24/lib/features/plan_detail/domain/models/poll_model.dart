
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final bool isVotedByMe;
  
  PollOption({
    required this.id, 
    required this.text, 
    this.voteCount = 0, 
    this.isVotedByMe = false,
  });

  factory PollOption.fromJson(Map<String, dynamic> json, String? currentUserId) {
    // Handling Supabase count response
    int count = 0;
    bool voted = false;

    if (json['poll_votes'] != null) {
      if (json['poll_votes'] is List) {
        final votesList = json['poll_votes'] as List;
        // If we queried for count, it might be the first element
        if (votesList.isNotEmpty && votesList.first is Map && votesList.first.containsKey('count')) {
          count = votesList.first['count'] ?? 0;
        } else {
           // If we just got a list of votes, count them
           count = votesList.length;
        }
        
        // If we also queried for user_id to check if I voted
        // Check if elements are maps before accessing
        voted = votesList.any((v) => v is Map && v['user_id'] == currentUserId);
      } else if (json['poll_votes'] is Map) {
        count = json['poll_votes']['count'] ?? 0;
      }
    }

    return PollOption(
      id: json['id']?.toString() ?? 'unknown_id',
      text: json['text']?.toString() ?? 'Sin texto',
      voteCount: count,
      isVotedByMe: voted,
    );
  }
}

class Poll {
  final String id;
  final String question;
  final bool isClosed;
  final String status; // 'active', 'draft'
  final DateTime? expiresAt;
  final List<PollOption> options;

  Poll({required this.id, required this.question, required this.options, this.isClosed = false, this.status = 'active', this.expiresAt});

  factory Poll.fromJson(Map<String, dynamic> json, String? currentUserId) {
    final List<dynamic> optionsList = json['poll_options'] ?? [];
    return Poll(
      id: json['id']?.toString() ?? 'unknown_id',
      question: json['question']?.toString() ?? 'Sin pregunta',
      isClosed: json['is_closed'] ?? false,
      status: json['status'] ?? 'active',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      options: optionsList.map((e) => PollOption.fromJson(e, currentUserId)).toList(),
    );
  }
}
