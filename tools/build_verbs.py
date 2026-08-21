#!/usr/bin/env python3
"""Generate app/assets/course/verbs.json: a curated Spanish conjugation dataset.

~50 common Spanish verbs x 6 tenses x 6 persons, with ES/EN/AR tense labels.
Regular verbs are conjugated by rule; irregular verbs carry explicit tables.
Latin American conventions (ustedes, no vosotros; no voseo). Idempotent.

Usage: python3 build_verbs.py [out_path]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    ROOT, "..", "app", "assets", "course", "verbs.json")

TENSES = {
    "present":     {"es": "Presente",               "en": "Present",          "ar": "المضارع"},
    "preterite":   {"es": "Pretérito",              "en": "Preterite (Past)", "ar": "الماضي البسيط"},
    "imperfect":   {"es": "Pretérito Imperfecto",   "en": "Imperfect",        "ar": "الماضي المستمر"},
    "future":      {"es": "Futuro",                 "en": "Future",           "ar": "المستقبل"},
    "conditional": {"es": "Condicional",            "en": "Conditional",      "ar": "الشرطي"},
    "subjunctive": {"es": "Subjuntivo Presente",    "en": "Subjunctive",      "ar": "المضارع المنصوب"},
}
PERSONS = ["yo", "tú", "él/ella", "nosotros", "ustedes", "ellos/ellas"]


def add(stem, sfx):
    return [stem + s for s in sfx]


def regular(cls, stem, inf):
    """Return dict of 6 tenses for a regular Spanish verb."""
    if cls == "ar":
        return {
            "present":     add(stem, ["o", "as", "a", "amos", "an", "an"]),
            "preterite":   add(stem, ["é", "aste", "ó", "amos", "aron", "aron"]),
            "imperfect":   add(stem, ["aba", "abas", "aba", "ábamos", "aban", "aban"]),
            "future":      add(inf, ["é", "ás", "á", "emos", "án", "án"]),
            "conditional": add(inf, ["ía", "ías", "ía", "íamos", "ían", "ían"]),
            "subjunctive": add(stem, ["e", "es", "e", "emos", "en", "en"]),
        }
    if cls == "er":
        return {
            "present":     add(stem, ["o", "es", "e", "emos", "en", "en"]),
            "preterite":   add(stem, ["í", "iste", "ió", "imos", "ieron", "ieron"]),
            "imperfect":   add(stem, ["ía", "ías", "ía", "íamos", "ían", "ían"]),
            "future":      add(inf, ["é", "ás", "á", "emos", "án", "án"]),
            "conditional": add(inf, ["ía", "ías", "ía", "íamos", "ían", "ían"]),
            "subjunctive": add(stem, ["a", "as", "a", "amos", "an", "an"]),
        }
    # ir-class
    return {
        "present":     add(stem, ["o", "es", "e", "imos", "en", "en"]),
        "preterite":   add(stem, ["í", "iste", "ió", "imos", "ieron", "ieron"]),
        "imperfect":   add(stem, ["ía", "ías", "ía", "íamos", "ían", "ían"]),
        "future":      add(inf, ["é", "ás", "á", "emos", "án", "án"]),
        "conditional": add(inf, ["ía", "ías", "ía", "íamos", "ían", "ían"]),
        "subjunctive": add(stem, ["a", "as", "a", "amos", "an", "an"]),
    }


VERBS = [
    # irregular: (infinitive, en, ar, tables)
    ("ser", "to be", "يكون", {
        "present":     ["soy", "eres", "es", "somos", "son", "son"],
        "preterite":   ["fui", "fuiste", "fue", "fuimos", "fueron", "fueron"],
        "imperfect":   ["era", "eras", "era", "éramos", "eran", "eran"],
        "future":      ["seré", "serás", "será", "seremos", "serán", "serán"],
        "conditional": ["sería", "serías", "sería", "seríamos", "serían", "serían"],
        "subjunctive": ["sea", "seas", "sea", "seamos", "sean", "sean"],
    }),
    ("estar", "to be (temporary)", "يكون (حالة)", {
        "present":     ["estoy", "estás", "está", "estamos", "están", "están"],
        "preterite":   ["estuve", "estuviste", "estuvo", "estuvimos", "estuvieron", "estuvieron"],
        "imperfect":   ["estaba", "estabas", "estaba", "estábamos", "estaban", "estaban"],
        "future":      ["estaré", "estarás", "estará", "estaremos", "estarán", "estarán"],
        "conditional": ["estaría", "estarías", "estaría", "estaríamos", "estarían", "estarían"],
        "subjunctive": ["esté", "estés", "esté", "estemos", "estén", "estén"],
    }),
    ("tener", "to have", "يملك", {
        "present":     ["tengo", "tienes", "tiene", "tenemos", "tienen", "tienen"],
        "preterite":   ["tuve", "tuviste", "tuvo", "tuvimos", "tuvieron", "tuvieron"],
        "imperfect":   ["tenía", "tenías", "tenía", "teníamos", "tenían", "tenían"],
        "future":      ["tendré", "tendrás", "tendrá", "tendremos", "tendrán", "tendrán"],
        "conditional": ["tendría", "tendrías", "tendría", "tendríamos", "tendrían", "tendrían"],
        "subjunctive": ["tenga", "tengas", "tenga", "tengamos", "tengan", "tengan"],
    }),
    ("haber", "there to be / auxiliary", "يوجد", {
        "present":     ["he", "has", "ha", "hemos", "han", "han"],
        "preterite":   ["hube", "hubiste", "hubo", "hubimos", "hubieron", "hubieron"],
        "imperfect":   ["había", "habías", "había", "habíamos", "habían", "habían"],
        "future":      ["habré", "habrás", "habrá", "habremos", "habrán", "habrán"],
        "conditional": ["habría", "habrías", "habría", "habríamos", "habrían", "habrían"],
        "subjunctive": ["haya", "hayas", "haya", "hayamos", "hayan", "hayan"],
    }),
    ("hacer", "to do / make", "يفعل / يصنع", {
        "present":     ["hago", "haces", "hace", "hacemos", "hacen", "hacen"],
        "preterite":   ["hice", "hiciste", "hizo", "hicimos", "hicieron", "hicieron"],
        "imperfect":   ["hacía", "hacías", "hacía", "hacíamos", "hacían", "hacían"],
        "future":      ["haré", "harás", "hará", "haremos", "harán", "harán"],
        "conditional": ["haría", "harías", "haría", "haríamos", "harían", "harían"],
        "subjunctive": ["haga", "hagas", "haga", "hagamos", "hagan", "hagan"],
    }),
    ("ir", "to go", "يذهب", {
        "present":     ["voy", "vas", "va", "vamos", "van", "van"],
        "preterite":   ["fui", "fuiste", "fue", "fuimos", "fueron", "fueron"],
        "imperfect":   ["iba", "ibas", "iba", "íbamos", "iban", "iban"],
        "future":      ["iré", "irás", "irá", "iremos", "irán", "irán"],
        "conditional": ["iría", "irías", "iría", "iríamos", "irían", "irían"],
        "subjunctive": ["vaya", "vayas", "vaya", "vayamos", "vayan", "vayan"],
    }),
    ("venir", "to come", "يأتي", {
        "present":     ["vengo", "vienes", "viene", "venimos", "vienen", "vienen"],
        "preterite":   ["vine", "viniste", "vino", "vinimos", "vinieron", "vinieron"],
        "imperfect":   ["venía", "venías", "venía", "veníamos", "venían", "venían"],
        "future":      ["vendré", "vendrás", "vendrá", "vendremos", "vendrán", "vendrán"],
        "conditional": ["vendría", "vendrías", "vendría", "vendríamos", "vendrían", "vendrían"],
        "subjunctive": ["venga", "vengas", "venga", "vengamos", "vengan", "vengan"],
    }),
    ("decir", "to say", "يقول", {
        "present":     ["digo", "dices", "dice", "decimos", "dicen", "dicen"],
        "preterite":   ["dije", "dijiste", "dijo", "dijimos", "dijeron", "dijeron"],
        "imperfect":   ["decía", "decías", "decía", "decíamos", "decían", "decían"],
        "future":      ["diré", "dirás", "dirá", "diremos", "dirán", "dirán"],
        "conditional": ["diría", "dirías", "diría", "diríamos", "dirían", "dirían"],
        "subjunctive": ["diga", "digas", "diga", "digamos", "digan", "digan"],
    }),
    ("saber", "to know (facts)", "يعرف", {
        "present":     ["sé", "sabes", "sabe", "sabemos", "saben", "saben"],
        "preterite":   ["supe", "supiste", "supo", "supimos", "supieron", "supieron"],
        "imperfect":   ["sabía", "sabías", "sabía", "sabíamos", "sabían", "sabían"],
        "future":      ["sabré", "sabrás", "sabrá", "sabremos", "sabrán", "sabrán"],
        "conditional": ["sabría", "sabrías", "sabría", "sabríamos", "sabrían", "sabrían"],
        "subjunctive": ["sepa", "sepas", "sepa", "sepamos", "sepan", "sepan"],
    }),
    ("poder", "to be able to", "يستطيع", {
        "present":     ["puedo", "puedes", "puede", "podemos", "pueden", "pueden"],
        "preterite":   ["pude", "pudiste", "pudo", "pudimos", "pudieron", "pudieron"],
        "imperfect":   ["podía", "podías", "podía", "podíamos", "podían", "podían"],
        "future":      ["podré", "podrás", "podrá", "podremos", "podrán", "podrán"],
        "conditional": ["podría", "podrías", "podría", "podríamos", "podrían", "podrían"],
        "subjunctive": ["pueda", "puedas", "pueda", "podamos", "puedan", "puedan"],
    }),
    ("querer", "to want", "يريد", {
        "present":     ["quiero", "quieres", "quiere", "queremos", "quieren", "quieren"],
        "preterite":   ["quise", "quisiste", "quiso", "quisimos", "quisieron", "quisieron"],
        "imperfect":   ["quería", "querías", "quería", "queríamos", "querían", "querían"],
        "future":      ["querré", "querrás", "querrá", "querremos", "querrán", "querrán"],
        "conditional": ["querría", "querrías", "querría", "querríamos", "querrían", "querrían"],
        "subjunctive": ["quiera", "quieras", "quiera", "queramos", "quieran", "quieran"],
    }),
    ("ver", "to see", "يرى", {
        "present":     ["veo", "ves", "ve", "vemos", "ven", "ven"],
        "preterite":   ["vi", "viste", "vio", "vimos", "vieron", "vieron"],
        "imperfect":   ["veía", "veías", "veía", "veíamos", "veían", "veían"],
        "future":      ["veré", "verás", "verá", "veremos", "verán", "verán"],
        "conditional": ["vería", "verías", "vería", "veríamos", "verían", "verían"],
        "subjunctive": ["vea", "veas", "vea", "veamos", "vean", "vean"],
    }),
    ("dar", "to give", "يعطي", {
        "present":     ["doy", "das", "da", "damos", "dan", "dan"],
        "preterite":   ["di", "diste", "dio", "dimos", "dieron", "dieron"],
        "imperfect":   ["daba", "dabas", "daba", "dábamos", "daban", "daban"],
        "future":      ["daré", "darás", "dará", "daremos", "darán", "darán"],
        "conditional": ["daría", "darías", "daría", "daríamos", "darían", "darían"],
        "subjunctive": ["dé", "des", "dé", "demos", "den", "den"],
    }),
    ("poner", "to put", "يضع", {
        "present":     ["pongo", "pones", "pone", "ponemos", "ponen", "ponen"],
        "preterite":   ["puse", "pusiste", "puso", "pusimos", "pusieron", "pusieron"],
        "imperfect":   ["ponía", "ponías", "ponía", "poníamos", "ponían", "ponían"],
        "future":      ["pondré", "pondrás", "pondrá", "pondremos", "pondrán", "pondrán"],
        "conditional": ["pondría", "pondrías", "pondría", "pondríamos", "pondrían", "pondrían"],
        "subjunctive": ["ponga", "pongas", "ponga", "pongamos", "pongan", "pongan"],
    }),
    ("salir", "to leave / go out", "يخرج", {
        "present":     ["salgo", "sales", "sale", "salimos", "salen", "salen"],
        "preterite":   ["salí", "saliste", "salió", "salimos", "salieron", "salieron"],
        "imperfect":   ["salía", "salías", "salía", "salíamos", "salían", "salían"],
        "future":      ["saldré", "saldrás", "saldrá", "saldremos", "saldrán", "saldrán"],
        "conditional": ["saldría", "saldrías", "saldría", "saldríamos", "saldrían", "saldrían"],
        "subjunctive": ["salga", "salgas", "salga", "salgamos", "salgan", "salgan"],
    }),
    ("traer", "to bring", "يجلب", {
        "present":     ["traigo", "traes", "trae", "traemos", "traen", "traen"],
        "preterite":   ["traje", "trajiste", "trajo", "trajimos", "trajeron", "trajeron"],
        "imperfect":   ["traía", "traías", "traía", "traíamos", "traían", "traían"],
        "future":      ["traeré", "traerás", "traerá", "traeremos", "traerán", "traerán"],
        "conditional": ["traería", "traerías", "traería", "traeríamos", "traerían", "traerían"],
        "subjunctive": ["traiga", "traigas", "traiga", "traigamos", "traigan", "traigan"],
    }),
    ("oír", "to hear / listen", "يسمع", {
        "present":     ["oigo", "oyes", "oye", "oímos", "oyen", "oyen"],
        "preterite":   ["oí", "oíste", "oyó", "oímos", "oyeron", "oyeron"],
        "imperfect":   ["oía", "oías", "oía", "oíamos", "oían", "oían"],
        "future":      ["oiré", "oirás", "oirá", "oiremos", "oirán", "oirán"],
        "conditional": ["oiría", "oirías", "oiría", "oiríamos", "oirían", "oirían"],
        "subjunctive": ["oiga", "oigas", "oiga", "oigamos", "oigan", "oigan"],
    }),
    ("leer", "to read", "يقرأ", {
        "present":     ["leo", "lees", "lee", "leemos", "leen", "leen"],
        "preterite":   ["leí", "leíste", "leyó", "leímos", "leyeron", "leyeron"],
        "imperfect":   ["leía", "leías", "leía", "leíamos", "leían", "leían"],
        "future":      ["leeré", "leerás", "leerá", "leeremos", "leerán", "leerán"],
        "conditional": ["leería", "leerías", "leería", "leeríamos", "leerían", "leerían"],
        "subjunctive": ["lea", "leas", "lea", "leamos", "lean", "lean"],
    }),
]

# semi-irregular verbs: explicit tables
SEMI = {
    "pensar": {
        "present":     ["pienso", "piensas", "piensa", "pensamos", "piensan", "piensan"],
        "preterite":   ["pensé", "pensaste", "pensó", "pensamos", "pensaron", "pensaron"],
        "imperfect":   ["pensaba", "pensabas", "pensaba", "pensábamos", "pensaban", "pensaban"],
        "future":      ["pensaré", "pensarás", "pensará", "pensaremos", "pensarán", "pensarán"],
        "conditional": ["pensaría", "pensarías", "pensaría", "pensaríamos", "pensarían", "pensarían"],
        "subjunctive": ["piense", "pienses", "piense", "pensemos", "piensen", "piensen"],
    },
    "volver": {
        "present":     ["vuelvo", "vuelves", "vuelve", "volvemos", "vuelven", "vuelven"],
        "preterite":   ["volví", "volviste", "volvió", "volvimos", "volvieron", "volvieron"],
        "imperfect":   ["volvía", "volvías", "volvía", "volvíamos", "volvían", "volvían"],
        "future":      ["volveré", "volverás", "volverá", "volveremos", "volverán", "volverán"],
        "conditional": ["volvería", "volverías", "volvería", "volveríamos", "volverían", "volverían"],
        "subjunctive": ["vuelva", "vuelvas", "vuelva", "volvamos", "vuelvan", "vuelvan"],
    },
    "encontrar": {
        "present":     ["encuentro", "encuentras", "encuentra", "encontramos", "encuentran", "encuentran"],
        "preterite":   ["encontré", "encontraste", "encontró", "encontramos", "encontraron", "encontraron"],
        "imperfect":   ["encontraba", "encontrabas", "encontraba", "encontrábamos", "encontraban", "encontraban"],
        "future":      ["encontraré", "encontrarás", "encontrará", "encontraremos", "encontrarán", "encontrarán"],
        "conditional": ["encontraría", "encontrarías", "encontraría", "encontraríamos", "encontrarían", "encontrarían"],
        "subjunctive": ["encuentre", "encuentres", "encuentre", "encontremos", "encuentren", "encuentren"],
    },
    "dormir": {
        "present":     ["duermo", "duermes", "duerme", "dormimos", "duermen", "duermen"],
        "preterite":   ["dormí", "dormiste", "durmió", "dormimos", "durmieron", "durmieron"],
        "imperfect":   ["dormía", "dormías", "dormía", "dormíamos", "dormían", "dormían"],
        "future":      ["dormiré", "dormirás", "dormirá", "dormiremos", "dormirán", "dormirán"],
        "conditional": ["dormiría", "dormirías", "dormiría", "dormiríamos", "dormirían", "dormirían"],
        "subjunctive": ["duerma", "duermas", "duerma", "durmamos", "duerman", "duerman"],
    },
    "sentir": {
        "present":     ["siento", "sientes", "siente", "sentimos", "sienten", "sienten"],
        "preterite":   ["sentí", "sentiste", "sintió", "sentimos", "sintieron", "sintieron"],
        "imperfect":   ["sentía", "sentías", "sentía", "sentíamos", "sentían", "sentían"],
        "future":      ["sentiré", "sentirás", "sentirá", "sentiremos", "sentirán", "sentirán"],
        "conditional": ["sentiría", "sentirías", "sentiría", "sentiríamos", "sentirían", "sentirían"],
        "subjunctive": ["sienta", "sientas", "sienta", "sintamos", "sientan", "sientan"],
    },
    "pedir": {
        "present":     ["pido", "pides", "pide", "pedimos", "piden", "piden"],
        "preterite":   ["pedí", "pediste", "pidió", "pedimos", "pidieron", "pidieron"],
        "imperfect":   ["pedía", "pedías", "pedía", "pedíamos", "pedían", "pedían"],
        "future":      ["pediré", "pedirás", "pedirá", "pediremos", "pedirán", "pedirán"],
        "conditional": ["pediría", "pedirías", "pediría", "pediríamos", "pedirían", "pedirían"],
        "subjunctive": ["pida", "pidas", "pida", "pidamos", "pidan", "pidan"],
    },
    "seguir": {
        "present":     ["sigo", "sigues", "sigue", "seguimos", "siguen", "siguen"],
        "preterite":   ["seguí", "seguiste", "siguió", "seguimos", "siguieron", "siguieron"],
        "imperfect":   ["seguía", "seguías", "seguía", "seguíamos", "seguían", "seguían"],
        "future":      ["seguiré", "seguirás", "seguirá", "seguiremos", "seguirán", "seguirán"],
        "conditional": ["seguiría", "seguirías", "seguiría", "seguiríamos", "seguirían", "seguirían"],
        "subjunctive": ["siga", "sigas", "siga", "sigamos", "sigan", "sigan"],
    },
    "jugar": {
        "present":     ["juego", "juegas", "juega", "jugamos", "juegan", "juegan"],
        "preterite":   ["jugué", "jugaste", "jugó", "jugamos", "jugaron", "jugaron"],
        "imperfect":   ["jugaba", "jugabas", "jugaba", "jugábamos", "jugaban", "jugaban"],
        "future":      ["jugaré", "jugarás", "jugará", "jugaremos", "jugarán", "jugarán"],
        "conditional": ["jugaría", "jugarías", "jugaría", "jugaríamos", "jugarían", "jugarían"],
        "subjunctive": ["juegue", "juegues", "juegue", "juguemos", "jueguen", "jueguen"],
    },
    "conocer": {
        "present":     ["conozco", "conoces", "conoce", "conocemos", "conocen", "conocen"],
        "preterite":   ["conocí", "conociste", "conoció", "conocimos", "conocieron", "conocieron"],
        "imperfect":   ["conocía", "conocías", "conocía", "conocíamos", "conocían", "conocían"],
        "future":      ["conoceré", "conocerás", "conocerá", "conoceremos", "conocerán", "conocerán"],
        "conditional": ["conocería", "conocerías", "conocería", "conoceríamos", "conocerían", "conocerían"],
        "subjunctive": ["conozca", "conozcas", "conozca", "conozcamos", "conozcan", "conozcan"],
    },
    "conseguir": {
        "present":     ["consigo", "consigues", "consigue", "conseguimos", "consiguen", "consiguen"],
        "preterite":   ["conseguí", "conseguiste", "consiguió", "conseguimos", "consiguieron", "consiguieron"],
        "imperfect":   ["conseguía", "conseguías", "conseguía", "conseguíamos", "conseguían", "conseguían"],
        "future":      ["conseguiré", "conseguirás", "conseguirá", "conseguiremos", "conseguirán", "conseguirán"],
        "conditional": ["conseguiría", "conseguirías", "conseguiría", "conseguiríamos", "conseguirían", "conseguirían"],
        "subjunctive": ["consiga", "consigas", "consiga", "consigamos", "consigan", "consigan"],
    },
    "empezar": {
        "present":     ["empiezo", "empiezas", "empieza", "empezamos", "empiezan", "empiezan"],
        "preterite":   ["empecé", "empezaste", "empezó", "empezamos", "empezaron", "empezaron"],
        "imperfect":   ["empezaba", "empezabas", "empezaba", "empezábamos", "empezaban", "empezaban"],
        "future":      ["empezaré", "empezarás", "empezará", "empezaremos", "empezarán", "empezarán"],
        "conditional": ["empezaría", "empezarías", "empezaría", "empezaríamos", "empezarían", "empezarían"],
        "subjunctive": ["empiece", "empieces", "empiece", "empecemos", "empiecen", "empiecen"],
    },
    "pagar": {
        "present":     ["pago", "pagas", "paga", "pagamos", "pagan", "pagan"],
        "preterite":   ["pagué", "pagaste", "pagó", "pagamos", "pagaron", "pagaron"],
        "imperfect":   ["pagaba", "pagabas", "pagaba", "pagábamos", "pagaban", "pagaban"],
        "future":      ["pagaré", "pagarás", "pagará", "pagaremos", "pagarán", "pagarán"],
        "conditional": ["pagaría", "pagarías", "pagaría", "pagaríamos", "pagarían", "pagarían"],
        "subjunctive": ["pague", "pagues", "pague", "paguemos", "paguen", "paguen"],
    },
    "buscar": {
        "present":     ["busco", "buscas", "busca", "buscamos", "buscan", "buscan"],
        "preterite":   ["busqué", "buscaste", "buscó", "buscamos", "buscaron", "buscaron"],
        "imperfect":   ["buscaba", "buscabas", "buscaba", "buscábamos", "buscaban", "buscaban"],
        "future":      ["buscaré", "buscarás", "buscará", "buscaremos", "buscarán", "buscarán"],
        "conditional": ["buscaría", "buscarías", "buscaría", "buscaríamos", "buscarían", "buscarían"],
        "subjunctive": ["busque", "busques", "busque", "busquemos", "busquen", "busquen"],
    },
    "llegar": {
        "present":     ["llego", "llegas", "llega", "llegamos", "llegan", "llegan"],
        "preterite":   ["llegué", "llegaste", "llegó", "llegamos", "llegaron", "llegaron"],
        "imperfect":   ["llegaba", "llegabas", "llegaba", "llegábamos", "llegaban", "llegaban"],
        "future":      ["llegaré", "llegarás", "llegará", "llegaremos", "llegarán", "llegarán"],
        "conditional": ["llegaría", "llegarías", "llegaría", "llegaríamos", "llegarían", "llegarían"],
        "subjunctive": ["llegue", "llegues", "llegue", "lleguemos", "lleguen", "lleguen"],
    },
    "creer": {
        "present":     ["creo", "crees", "cree", "creemos", "creen", "creen"],
        "preterite":   ["creí", "creíste", "creyó", "creímos", "creyeron", "creyeron"],
        "imperfect":   ["creía", "creías", "creía", "creíamos", "creían", "creían"],
        "future":      ["creeré", "creerás", "creerá", "creeremos", "creerán", "creerán"],
        "conditional": ["creería", "creerías", "creería", "creeríamos", "creerían", "creerían"],
        "subjunctive": ["crea", "creas", "crea", "creamos", "crean", "crean"],
    },
    "entender": {
        "present":     ["entiendo", "entiendes", "entiende", "entendemos", "entienden", "entienden"],
        "preterite":   ["entendí", "entendiste", "entendió", "entendimos", "entendieron", "entendieron"],
        "imperfect":   ["entendía", "entendías", "entendía", "entendíamos", "entendían", "entendían"],
        "future":      ["entenderé", "entenderás", "entenderá", "entenderemos", "entenderán", "entenderán"],
        "conditional": ["entendería", "entenderías", "entendería", "entenderíamos", "entenderían", "entenderían"],
        "subjunctive": ["entienda", "entiendas", "entienda", "entendamos", "entiendan", "entiendan"],
    },
}

# stems for regular verbs: verb -> (class, stem, infinitive)
REGULAR = {
    "hablar":      ("ar", "habl", "hablar"),
    "trabajar":    ("ar", "trabaj", "trabajar"),
    "comprar":     ("ar", "compr", "comprar"),
    "necesitar":   ("ar", "necesit", "necesitar"),
    "estudiar":    ("ar", "estudi", "estudiar"),
    "viajar":      ("ar", "viaj", "viajar"),
    "mirar":       ("ar", "mir", "mirar"),
    "escuchar":    ("ar", "escuch", "escuchar"),
    "usar":        ("ar", "us", "usar"),
    "ayudar":      ("ar", "ayud", "ayudar"),
    "preguntar":   ("ar", "pregunt", "preguntar"),
    "esperar":     ("ar", "esper", "esperar"),
    "llamar":      ("ar", "llam", "llamar"),
    "caminar":     ("ar", "camin", "caminar"),
    "ganar":       ("ar", "gan", "ganar"),
    "bailar":      ("ar", "bail", "bailar"),
    "cantar":      ("ar", "cant", "cantar"),
    "visitar":     ("ar", "visit", "visitar"),
    "cocinar":     ("ar", "cocin", "cocinar"),
    "comer":       ("er", "com", "comer"),
    "beber":       ("er", "beb", "beber"),
    "vender":      ("er", "vend", "vender"),
    "aprender":    ("er", "aprend", "aprender"),
    "correr":      ("er", "corr", "correr"),
    "comprender":  ("er", "comprend", "comprender"),
    "deber":       ("er", "deb", "deber"),
    "responder":   ("er", "respond", "responder"),
    "vivir":       ("ir", "viv", "vivir"),
    "escribir":    ("ir", "escrib", "escribir"),
    "abrir":       ("ir", "abr", "abrir"),
    "recibir":     ("ir", "recib", "recibir"),
    "subir":       ("ir", "sub", "subir"),
    "decidir":     ("ir", "decid", "decidir"),
    "cumplir":     ("ir", "cumpl", "cumplir"),
    "compartir":   ("ir", "compart", "compartir"),
    "cubrir":      ("ir", "cubr", "cubrir"),
    "sufrir":      ("ir", "sufr", "sufrir"),
    "unir":        ("ir", "un", "unir"),
    "existir":     ("ir", "exist", "existir"),
    "insistir":    ("ir", "insist", "insistir"),
}


TRANSL = {
    "hablar": "to speak",
    "hablar_ar": "يتكلم",
    "trabajar": "to work",
    "trabajar_ar": "يعمل",
    "comprar": "to buy",
    "comprar_ar": "يشتري",
    "necesitar": "to need",
    "necesitar_ar": "يحتاج",
    "estudiar": "to study",
    "estudiar_ar": "يدرس",
    "viajar": "to travel",
    "viajar_ar": "يسافر",
    "mirar": "to look",
    "mirar_ar": "ينظر",
    "escuchar": "to listen",
    "escuchar_ar": "يستمع",
    "usar": "to use",
    "usar_ar": "يستخدم",
    "ayudar": "to help",
    "ayudar_ar": "يساعد",
    "preguntar": "to ask",
    "preguntar_ar": "يسأل",
    "esperar": "to wait / hope",
    "esperar_ar": "ينتظر",
    "llamar": "to call",
    "llamar_ar": "ينادي",
    "caminar": "to walk",
    "caminar_ar": "يمشي",
    "ganar": "to win / earn",
    "ganar_ar": "يربح",
    "bailar": "to dance",
    "bailar_ar": "يرقص",
    "cantar": "to sing",
    "cantar_ar": "يغني",
    "visitar": "to visit",
    "visitar_ar": "يزور",
    "cocinar": "to cook",
    "cocinar_ar": "يطبخ",
    "comer": "to eat",
    "comer_ar": "يأكل",
    "beber": "to drink",
    "beber_ar": "يشرب",
    "vender": "to sell",
    "vender_ar": "يبيع",
    "aprender": "to learn",
    "aprender_ar": "يتعلم",
    "correr": "to run",
    "correr_ar": "يجري",
    "comprender": "to understand",
    "comprender_ar": "يفهم",
    "deber": "to owe / must",
    "deber_ar": "يجب",
    "responder": "to answer",
    "responder_ar": "يجيب",
    "vivir": "to live",
    "vivir_ar": "يعيش",
    "escribir": "to write",
    "escribir_ar": "يكتب",
    "abrir": "to open",
    "abrir_ar": "يفتح",
    "recibir": "to receive",
    "recibir_ar": "يستلم",
    "subir": "to go up",
    "subir_ar": "يصعد",
    "decidir": "to decide",
    "decidir_ar": "يقرر",
    "cumplir": "to fulfill",
    "cumplir_ar": "ينجز",
    "compartir": "to share",
    "compartir_ar": "يشارك",
    "cubrir": "to cover",
    "cubrir_ar": "يغطي",
    "sufrir": "to suffer",
    "sufrir_ar": "يعاني",
    "unir": "to unite",
    "unir_ar": "يوحد",
    "existir": "to exist",
    "existir_ar": "يوجد",
    "insistir": "to insist",
    "insistir_ar": "يصر",
    "pensar": "to think",
    "pensar_ar": "يفكر",
    "volver": "to return",
    "volver_ar": "يعود",
    "encontrar": "to find / meet",
    "encontrar_ar": "يجد",
    "dormir": "to sleep",
    "dormir_ar": "ينام",
    "sentir": "to feel",
    "sentir_ar": "يشعر",
    "pedir": "to ask for / order",
    "pedir_ar": "يطلب",
    "seguir": "to follow / continue",
    "seguir_ar": "يتبع",
    "jugar": "to play",
    "jugar_ar": "يلعب",
    "conocer": "to know (people/places)",
    "conocer_ar": "يعرف",
    "conseguir": "to get / obtain",
    "conseguir_ar": "يحصل",
    "empezar": "to start / begin",
    "empezar_ar": "يبدأ",
    "pagar": "to pay",
    "pagar_ar": "يدفع",
    "buscar": "to look for",
    "buscar_ar": "يبحث",
    "llegar": "to arrive",
    "llegar_ar": "يصل",
    "creer": "to believe",
    "creer_ar": "يصدق",
    "entender": "to understand",
    "entender_ar": "يفهم"
}


def main():
    verbs_out = []
    for inf, en, ar, tables in VERBS:
        if tables is None:
            raise SystemExit(f"missing tables for {inf}")
        assert all(len(tables[t]) == 6 for t in TENSES), inf
        verbs_out.append({"inf": inf, "en": en, "ar": ar, **tables})
    for inf, (cls, stem, full) in REGULAR.items():
        tables = regular(cls, stem, full)
        assert all(len(tables[t]) == 6 for t in TENSES), inf
        verbs_out.append({"inf": inf, "en": TRANSL.get(inf, ""), "ar": TRANSL.get(inf + "_ar", ""), **tables})
    for inf, tables in SEMI.items():
        assert all(len(tables[t]) == 6 for t in TENSES), inf
        verbs_out.append({"inf": inf, "en": TRANSL.get(inf, ""), "ar": TRANSL.get(inf + "_ar", ""), **tables})

    data = {
        "tenses": TENSES,
        "persons": PERSONS,
        "verbs": verbs_out,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
    print(f"Wrote {len(verbs_out)} verbs to {OUT}")


if __name__ == "__main__":
    main()