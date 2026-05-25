class LifeCanvasNode {
  final String id;
  final String type;
  final String label;
  final double importance;
  final String? summary;
  final String? emotion;
  final List<String> themes;
  final List<String> people;
  final DateTime? timestamp;
  final DateTime createdAt;

  LifeCanvasNode({
    required this.id,
    required this.type,
    required this.label,
    required this.importance,
    this.summary,
    this.emotion,
    required this.themes,
    required this.people,
    this.timestamp,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'label': label,
      'importance': importance,
      'created_at': createdAt.toIso8601String(),
      'metadata': {
        'summary': summary,
        'emotion': emotion,
        'themes': themes,
        'people': people,
        'timestamp': timestamp?.toIso8601String(),
      }
    };
  }

  factory LifeCanvasNode.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
    
    // Parse themes list
    final rawThemes = metadata['themes'] as List?;
    final parsedThemes = rawThemes != null
        ? rawThemes.map((t) => t.toString()).toList()
        : <String>[];

    // Parse people list
    final rawPeople = metadata['people'] as List?;
    final parsedPeople = rawPeople != null
        ? rawPeople.map((p) => p.toString()).toList()
        : <String>[];

    // Parse timestamp
    DateTime? parsedTimestamp;
    if (metadata['timestamp'] != null) {
      parsedTimestamp = DateTime.tryParse(metadata['timestamp'].toString());
    }

    return LifeCanvasNode(
      id: json['id'].toString(),
      type: json['type'] ?? 'LIFE_EVENT',
      label: json['label'] ?? '',
      importance: (json['importance'] as num? ?? 0.5).toDouble(),
      summary: metadata['summary'] as String?,
      emotion: metadata['emotion'] as String?,
      themes: parsedThemes,
      people: parsedPeople,
      timestamp: parsedTimestamp,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class LifeCanvasEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String relation;
  final double strength;

  LifeCanvasEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.relation,
    required this.strength,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_id': sourceId,
      'target_id': targetId,
      'relation': relation,
      'strength': strength,
    };
  }

  factory LifeCanvasEdge.fromJson(Map<String, dynamic> json) {
    return LifeCanvasEdge(
      id: json['id'].toString(),
      sourceId: json['source_id'].toString(),
      targetId: json['target_id'].toString(),
      relation: json['relation'] ?? '',
      strength: (json['strength'] as num? ?? 0.5).toDouble(),
    );
  }
}

class LifeCanvasGraph {
  final List<LifeCanvasNode> nodes;
  final List<LifeCanvasEdge> edges;

  LifeCanvasGraph({
    required this.nodes,
    required this.edges,
  });

  Map<String, dynamic> toJson() {
    return {
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'edges': edges.map((e) => e.toJson()).toList(),
    };
  }

  factory LifeCanvasGraph.fromJson(Map<String, dynamic> json) {
    final rawNodes = json['nodes'] as List? ?? [];
    final rawEdges = json['edges'] as List? ?? [];

    return LifeCanvasGraph(
      nodes: rawNodes.map((n) => LifeCanvasNode.fromJson(n)).toList(),
      edges: rawEdges.map((e) => LifeCanvasEdge.fromJson(e)).toList(),
    );
  }

  factory LifeCanvasGraph.empty() {
    return LifeCanvasGraph(nodes: [], edges: []);
  }
}
