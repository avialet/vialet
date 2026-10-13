import Foundation
import VialetCore

/// Les fiches HubManifest et le catalogue ne sont pas dignes de confiance : chaque rejet est teste.
let safetyTests: (String, [Test]) = ("Safety", [
    Test("repositoryMustBeAvialet") {
        expect(HubSafety.isValidRepository("avialet/pico"))
        expect(HubSafety.isValidRepository("avialet/Pico_2.x-b"))
        expect(!HubSafety.isValidRepository("avialet/."))
        expect(!HubSafety.isValidRepository("avialet/.."))
        expect(!HubSafety.isValidRepository("autre/pico"), "autre proprietaire")
        expect(!HubSafety.isValidRepository("avialet/pico/../x"), "segment de plus")
        expect(!HubSafety.isValidRepository("avialet/"), "nom vide")
        expect(!HubSafety.isValidRepository("avialet/pi co"), "espace")
        expect(!HubSafety.isValidRepository("avialet/pi?co"), "requete")
        expect(!HubSafety.isValidRepository("avialet/pi#co"), "fragment")
        expect(!HubSafety.isValidRepository("avialet/p\u{00EF}co"), "non ASCII")
        expect(!HubSafety.isValidRepository("AVIALET/pico"), "proprietaire exact")
        expect(!HubSafety.isValidRepository("avialet/" + String(repeating: "a", count: 101)), "trop long")
    },
    Test("releaseURLOnlyForValidRepository") {
        expectEqual(HubUpdates.releaseURL(repository: "avialet/pico"),
                    URL(string: "https://api.github.com/repos/avialet/pico/releases/latest"))
        expectEqual(HubUpdates.releaseURL(repository: "avialet/.."), nil)
        expectEqual(HubUpdates.releaseURL(repository: "evil/x"), nil)
    },
    Test("schemeRules") {
        expect(HubSafety.isAcceptableScheme("pico"))
        expect(HubSafety.isAcceptableScheme("allege2"))
        expect(HubSafety.isAcceptableScheme("a+b.c-d"))
        expect(!HubSafety.isAcceptableScheme(""), "vide")
        expect(!HubSafety.isAcceptableScheme("2pico"), "chiffre initial")
        expect(!HubSafety.isAcceptableScheme("Pico"), "majuscule")
        expect(!HubSafety.isAcceptableScheme("pi co"), "espace")
        expect(!HubSafety.isAcceptableScheme("pico:"), "deux-points")
        expect(!HubSafety.isAcceptableScheme(String(repeating: "a", count: 32)), "plus de 31 caracteres")
        expect(HubSafety.isAcceptableScheme(String(repeating: "a", count: 31)))
        for system in ["file", "http", "https", "ftp", "mailto", "tel", "sms", "facetime", "ssh", "smb", "afp", "vnc",
                       "javascript", "data", "about", "x-apple-systempreferences", "shortcuts", "applescript", "itms-apps",
                       "x-help-action", "help", "news", "message", "webcal", "ical", "maps", "music", "spotlight"] {
            expect(!HubSafety.isAcceptableScheme(system), "schema systeme \(system)")
        }
    },
    Test("manifestLocationMustBeAnAppInApplications") {
        let home = URL(fileURLWithPath: "/Users/a")
        func ok(_ path: String) -> Bool { HubSafety.isAcceptableAppPath(path, home: home) }
        expect(ok("/Applications/Pico.app"))
        expect(ok("/Applications/Outils/Pico.app"))
        expect(ok("/Users/a/Applications/Pico.app"))
        expect(!ok("/Applications/Pico"), "sans .app")
        expect(!ok("/Applications/script.sh"), "pas une app")
        expect(!ok("/Users/a/Downloads/Pico.app"), "hors Applications")
        expect(!ok("/tmp/Pico.app"))
        expect(!ok("/Applications/../tmp/Pico.app"), "remontee")
        expect(!ok("Pico.app"), "chemin relatif")
        expect(!ok(""))
    },
    Test("catalogOverOneMegabyteIsIgnored") {
        expectEqual(Catalog.maxSize, 1024 * 1024)
        var data = Data(catalogJSON.utf8)
        expect(Catalog.parse(data) != nil)
        data.append(Data(repeating: 0x20, count: Catalog.maxSize))
        expectEqual(Catalog.parse(data), nil)
    },
    Test("catalogCacheReadChecksSizeFirst") {
        try withTemporaryDirectory { dir in
            let small = dir.appendingPathComponent("petit.json")
            try Data(catalogJSON.utf8).write(to: small)
            expectEqual(Catalog.load(from: small)?.count, 4)
            let big = dir.appendingPathComponent("gros.json")
            var data = Data(catalogJSON.utf8)
            data.append(Data(repeating: 0x20, count: Catalog.maxSize))
            try data.write(to: big)
            expectEqual(Catalog.load(from: big), nil)
            expectEqual(Catalog.load(from: dir.appendingPathComponent("absent.json")), nil)
        }
    },
    Test("updatesMergeKeepsUncheckedApps") {
        let previous = ["fr.vialet.a": SemanticVersion(1), "fr.vialet.b": SemanticVersion(2), "fr.vialet.c": SemanticVersion(3)]
        // a et b interroges (a a jour, b en 2.1), c non interroge (quota) : c garde sa valeur.
        let merged = HubUpdates.merge(previous: previous, found: ["fr.vialet.b": SemanticVersion(2, 1)],
                                      checked: ["fr.vialet.a", "fr.vialet.b"])
        expectEqual(merged, ["fr.vialet.b": SemanticVersion(2, 1), "fr.vialet.c": SemanticVersion(3)])
    },
])
