// CLEAN: DTD parsing disabled. /check_security should NOT flag.
using System.IO;
using System.Xml;

namespace PetRescue.Clean.Xml;

public static class FeedImporter
{
    public static void Import(Stream xml)
    {
        var settings = new XmlReaderSettings
        {
            DtdProcessing = DtdProcessing.Prohibit,
            XmlResolver = null,
        };
        using var reader = XmlReader.Create(xml, settings);
        while (reader.Read()) { /* ... */ }
    }
}
