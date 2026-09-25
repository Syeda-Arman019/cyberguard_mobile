package com.example.cyberguard_mobile.autoprotection

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UrlExtractorTest {

    @Test
    fun `extracts https url with query and fragment`() {
        val urls = UrlExtractor.extract("Check https://example.com/x?a=1#f now")
        assertEquals(listOf("https://example.com/x?a=1#f"), urls)
    }

    @Test
    fun `extracts multiple links in one message`() {
        val urls = UrlExtractor.extract("see http://a.com and https://b.org/x ok")
        assertEquals(
            listOf("http://a.com", "https://b.org/x"),
            urls
        )
    }

    @Test
    fun `extracts www link without scheme`() {
        val urls = UrlExtractor.extract("visit www.example.com/page for info")
        assertEquals(listOf("https://www.example.com/page"), urls)
    }

    @Test
    fun `extracts bare shortener link without scheme`() {
        val urls = UrlExtractor.extract("quick one bit.ly/3xYzAbC thanks")
        assertEquals(listOf("https://bit.ly/3xYzAbC"), urls)
    }

    @Test
    fun `strips trailing sentence punctuation`() {
        val urls = UrlExtractor.extract("Open https://example.com/a?b=1, then reply.")
        assertEquals(listOf("https://example.com/a?b=1"), urls)
    }

    @Test
    fun `handles roman urdu text around links`() {
        val urls = UrlExtractor.extract(
            "Bhai ye link kholo https://pay-pk.xyz/login aur paise bhej do jaldi"
        )
        assertEquals(listOf("https://pay-pk.xyz/login"), urls)
    }

    @Test
    fun `handles urdu script text around links`() {
        val urls = UrlExtractor.extract(
            "براہ کرم https://example.com/verify پر جا کر اپنا اکاؤنٹ تصدیق کریں"
        )
        assertEquals(listOf("https://example.com/verify"), urls)
    }

    @Test
    fun `deduplicates repeated links`() {
        val urls = UrlExtractor.extract("http://x.com http://x.com http://x.com")
        assertEquals(listOf("http://x.com"), urls)
    }

    @Test
    fun `ignores email addresses`() {
        val urls = UrlExtractor.extract("mail me at someone@example.com please")
        assertTrue(urls.isEmpty() || urls.none { it.contains("@") })
    }

    @Test
    fun `empty and blank input yield nothing`() {
        assertTrue(UrlExtractor.extract(null).isEmpty())
        assertTrue(UrlExtractor.extract("").isEmpty())
        assertTrue(UrlExtractor.extract("   ").isEmpty())
        assertTrue(UrlExtractor.extract("no links here at all").isEmpty())
    }

    @Test
    fun `long message with link in middle is captured`() {
        val text = "Assalam o alaikum! Kal match dekha? " +
            "Tickets yahan se lo: https://tickets.example.pk/e/12345?ref=wa " +
            "Rates bohat ache hain, jaldi karo!"
        val urls = UrlExtractor.extract(text)
        assertEquals(listOf("https://tickets.example.pk/e/12345?ref=wa"), urls)
    }

    @Test
    fun `t co shortener with path is captured`() {
        val urls = UrlExtractor.extract("https://t.co/abcd123 via twitter")
        assertEquals(listOf("https://t.co/abcd123"), urls)
    }
}
