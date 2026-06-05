class ContactRecord {
  const ContactRecord(this.label);

  final String label;
}

class ContactSearchController {
  List<ContactRecord> search(List<ContactRecord> contacts, String query) {
    return contacts;
  }
}
