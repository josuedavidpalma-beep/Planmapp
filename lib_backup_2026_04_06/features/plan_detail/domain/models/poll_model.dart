
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final int quantity;
  final bool isVotedByMe;
  final Map<String, dynamic>? assigneeProfile;
  
  PollOption({
    required this.id, 
    required this.text, 
    this.voteCount = 0, 
    this.isVotedByMe = false,
    this.quantity = 1,
    this.assigneeProfile,
  });

  factory PollOption.fromJson(Map<String, dynamic> json, String? currentUserId) {
    // Handling Supabase count response
    int count = 0;
    bool voted = false;
    Map<String, dynamic>? assigneeProfile;

    if (json['poll_votes'] != null) {
      final votesList = json['poll_votes'] as List;
      count = votesList.length;
      voted = votesList.any((v) => v is Map && v['user_id'] == currentUserId);
      
      // For Item Polls, get the assignee (first voter)
      if (votesList.isNotEmpty) {
          final firstVote = votesList.first;
          if (firstVote['profiles'] != null) {
             assigneeProfile = firstVote['profiles'];
          }
      }
    }

    return PollOption(
      id: json['id']?.toString() ?? 'unknown_id',
      text: json['text']?.toString() ?? 'Sin texto',
      quantity: json['quantity'] ?? 1,
      voteCount: count,
      isVotedByMe: voted,
      assigneeProfile: assigneeProfile,
    );
  }
}

class Poll {
  final String id;
  final String question;
  final bool isClosed;
  final String status; // 'active', 'draft'
  final String type; // 'text', 'date', 'time', 'items'
  final DateTime? expiresAt;
  final List<PollOption> options;

  Poll({required this.id, required this.question, required this.options, this.isClosed = false, this.status = 'active', this.type = 'text', this.expiresAt});

  factory Poll.fromJson(Map<String, dynamic> json, String? currentUserId) {
    final List<dynamic> optionsList = json['poll_options'] ?? [];
    return Poll(
      id: json['id']?.toString() ?? 'unknown_id',
      question: json['question']?.toString() ?? 'Sin pregunta',
      isClosed: json['is_closed'] ?? false,
      status: json['status'] ?? 'active',
      type: json['type'] ?? 'text',
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'].toString()) : null,
      options: optionsList.map((e) => PollOption.fromJson(e, currentUserId)).toList(),
    );
  }

  Poll copyWith({
    String? id,
    String? question,
    List<PollOption>? options,
    bool? isClosed,
    String? status,
    String? type,
    DateTime? expiresAt,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      isClosed: isClosed ?? this.isClosed,
      status: status ?? this.status,
      type: type ?? this.type,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
