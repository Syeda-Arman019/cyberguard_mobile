package com.example.cyberguard_mobile.autoprotection

import android.util.Log

/**
 * Extracts and normalizes URLs from arbitrary notification text (long chat
 * messages, grouped summaries, SMS bodies, email subjects...).
 *
 * Covered forms:
 *  - explicit scheme:   https://example.com/x?a=1#f
 *  - www-prefixed:      www.example.com/page
 *  - bare shorteners:   bit.ly/3xYzAbC, tinyurl.com/abc123, t.co/xyz
 *
 * Trailing punctuation and closing brackets are stripped so URLs inside
 * sentences (even surrounded by Urdu / Roman Urdu text) are captured whole.
 */
object UrlExtractor {

    private const val TAG = "CyberGuardGatekeeper"

    /// http(s) or www. prefixed URLs.
    private val SCHEMED = Regex(
        """(?:https?://|www\.)[^\s<>"'(){}]+""",
        RegexOption.IGNORE_CASE
    )

    /// Bare links on well-known shortener hosts (no scheme needed).
    private val SHORTENER = Regex(
        """(?<![\w@./])((?:bit\.ly|tinyurl\.com|t\.co|goo\.gl|is\.gd|cutt\.ly|rb\.gy|shorturl\.at|rebrand\.ly|tiny\.cc|ow\.ly|buff\.ly|shorte\.st|adf\.ly)/(?:[^\s<>"'(){}]+)?)""",
        RegexOption.IGNORE_CASE
    )

    /// Characters that almost certainly belong to the sentence, not the URL.
    private val TRAILING_PUNCT = Regex("""[)\]}.>,;:!?'"]+$""")

    /// Well-known hosts that are themselves domains (never append a scheme guess of http for them).
    private const val SHORTENER_HOSTS = "bit.ly,tinyurl.com,t.co,goo.gl,is.gd,cutt.ly,rb.gy,shorturl.at,rebrand.ly,tiny.cc,ow.ly,buff.ly,shorte.st,adf.ly"

    /**
     * Returns every distinct, normalized URL found in [text], in order of
     * appearance. Empty input yields an empty list. Never throws.
     */
    fun extract(text: String?): List<String> {
        if (text.isNullOrBlank()) return emptyList()
        val found = LinkedHashSet<String>()
        try {
            SCHEMED.findAll(text).forEach { found.add(normalize(it.value)) }
            SHORTENER.findAll(text).forEach { found.add(normalize(it.groupValues[1])) }
        } catch (e: Exception) {
            Log.w(TAG, "URL extraction failed: ${e.message}")
        }
        return found.filter { it.isNotBlank() }
    }

    /**
     * Normalizes a raw match for analysis and deduplication:
     *  - trims sentence punctuation / stray brackets,
     *  - adds a scheme where the form implies one (www., shorteners),
     *  - keeps scheme, host and path EXACTLY as delivered otherwise
     *    (no re-encoding, no query stripping).
     */
    fun normalize(raw: String): String {
        var url = raw.trim().trim('"', '\'', '`')
        // Strip trailing sentence punctuation (keep it out of the URL).
        while (true) {
            val stripped = TRAILING_PUNCT.replace(url, "")
            if (stripped == url) break
            url = stripped
        }
        // Unbalanced opening bracket, e.g. "(https://x.com)" — close it out.
        val opens = url.count { it == '(' }
        val closes = url.count { it == ')' }
        if (opens > closes) url = url.dropLast(1)

        val lower = url.lowercase()
        return when {
            lower.startsWith("http://") || lower.startsWith("https://") -> url
            lower.startsWith("www.") -> "https://$url"
            // Bare shortener links always go over https in practice.
            SHORTENER_HOSTS.split(',').any { lower.startsWith(it) || lower.startsWith("$it/") } -> "https://$url"
            else -> url
        }
    }
}
