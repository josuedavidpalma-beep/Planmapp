
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
        if (votesList.isNotEmpty && votesList.first.containsKey('count')) {
          count = votesList.first['count'] ?? 0;
        }
        // If we also queried for user_id to check if I voted
        voted = votesList.any((v) => v['user_id'] == currentUserId);
      } else if (json['poll_votes'] is Map) {
        count = json['poll_votes']['count'] ?? 0;
      }
    }

    return PollOption(
      id: json['id'],
      text: json['text'],
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
  final List<PollOption> options;

  Poll({required this.id, required this.question, required this.options, this.isClosed = false, this.status = 'active'});

  factory Poll.fromJson(Map<String, dynamic> json, String? currentUserId) {
    final List<dynamic> optionsList = json['poll_options'] ?? [];
    return Poll(
      id: json['id'],
      question: json['question'],
      isClosed: json['is_closed'] ?? false,
      status: json['status'] ?? 'active',
      options: optionsList.map((e) => PollOption.fromJson(e, currentUserId)).toList(),
    );
  }
}
