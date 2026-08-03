class ChannelResource {
  final String title;
  final String type; // 'youtube', 'connection', 'pdf'
  final String url;

  const ChannelResource({
    required this.title,
    required this.type,
    required this.url,
  });
}

class Channel {
  final String id;
  final String name;
  final String followers;
  final String description;
  final List<ChannelResource> resources;

  const Channel({
    required this.id,
    required this.name,
    required this.followers,
    required this.description,
    required this.resources,
  });
}
