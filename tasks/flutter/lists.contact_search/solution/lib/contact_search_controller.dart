class Contact {
  const Contact({required this.name, required this.email});

  final String name;
  final String email;
}

class ContactSearchController {
  List<Contact> filter(List<Contact> contacts, String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final matches = normalizedQuery.isEmpty
        ? contacts
        : contacts.where((contact) {
            return contact.name.toLowerCase().contains(normalizedQuery) ||
                contact.email.toLowerCase().contains(normalizedQuery);
          });
    return matches.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }
}
