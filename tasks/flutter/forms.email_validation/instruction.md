Fix `EmailSignUpController` so sign-up email submission is normalized and validated safely.

Requirements:
- Preserve the public `EmailSignUpController` API.
- Reject blank or malformed email addresses with `invalidEmailMessage`.
- Accept normal email addresses that have one local part, one domain, and a dotted domain suffix.
- Trim leading/trailing whitespace and store accepted emails in lowercase.
- Clear stale error state after a later valid submission.
