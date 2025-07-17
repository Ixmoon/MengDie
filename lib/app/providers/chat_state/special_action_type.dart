/// Defines the types of special, non-primary generation actions that can be executed.
enum SpecialActionType {
  /// Generates "Help Me Reply" suggestions.
  helpMeReply,

  /// Processes and generates secondary XML content from a primary response.
  secondaryXml,

  /// Automatically generates a title for a chat based on its content.
  autoTitle,
}