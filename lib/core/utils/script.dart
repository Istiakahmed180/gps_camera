/// Wide letter spacing and capitals suit Latin headings but pull Bangla
/// (and other joined scripts) apart, so they are used only for Latin text.
bool isLatinText(String text) => !text.runes.any((r) => r > 0x024F);
