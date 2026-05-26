// VULN: CWE-611 XXE — XmlReader with DtdProcessing=Parse and a default XmlResolver.
// Expected /check_security finding: High, XML External Entity.
using System.IO;
using System.Xml;

namespace PetRescue.Vuln.Xxe;

public static class FeedImporter
{
    public static void Import(Stream xml)
    {
        // VULN: external entities are followed.
        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Parse,
            XmlResolver = new XmlUrlResolver(),
        };
        using var reader = XmlReader.Create(xml, settings);
        while (reader.Read()) { /* ... */ }
    }
}
