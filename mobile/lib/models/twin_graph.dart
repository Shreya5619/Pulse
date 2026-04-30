class TwinNode {
  final String id;
  final String label;
  final String type;
  final double x;
  final double y;
  final double risk;
  final Map<String, dynamic>? data;

  TwinNode({
    required this.id,
    required this.label,
    required this.type,
    required this.x,
    required this.y,
    this.risk = 0,
    this.data,
  });

  factory TwinNode.fromJson(Map<String, dynamic> json) {
    return TwinNode(
      id: json['id'],
      label: json['label'],
      type: json['type'],
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      risk: (json['risk'] as num? ?? 0).toDouble(),
      data: json['data'],
    );
  }
}

class TwinEdge {
  final String from;
  final String to;
  final String type;

  TwinEdge({
    required this.from,
    required this.to,
    required this.type,
  });

  factory TwinEdge.fromJson(Map<String, dynamic> json) {
    return TwinEdge(
      from: json['from'],
      to: json['to'],
      type: json['type'],
    );
  }
}

class TwinGraph {
  final List<TwinNode> nodes;
  final List<TwinEdge> edges;

  TwinGraph({required this.nodes, required this.edges});

  factory TwinGraph.fromJson(Map<String, dynamic> json) {
    return TwinGraph(
      nodes: (json['nodes'] as List).map((n) => TwinNode.fromJson(n)).toList(),
      edges: (json['edges'] as List).map((e) => TwinEdge.fromJson(e)).toList(),
    );
  }
}
