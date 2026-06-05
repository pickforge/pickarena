class Contact {
  const Contact({required this.name, required this.email});

  final String name;
  final String email;
}

class ContactSearchController {
  List<Contact> filter(List<Contact> contacts, String query) {
    if (query.isEmpty) return contacts;
    return contacts.where((contact) => contact.name.startsWith(query)).toList();
  }
}
