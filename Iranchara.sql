-- Création de la fonction JavaScript pour convertir l'hexadécimal HTML en texte Unicode car sans ça on ne récupère pas les caractères de l'arabe et du chinois mais juste leur code.
CREATE TEMP FUNCTION DecodeHtmlEntities(input STRING)
RETURNS STRING
LANGUAGE js AS """
  if (!input) return null;
  return input.replace(/&#x([0-9a-fA-F]+);/g, function(match, hex) {
    return String.fromCharCode(parseInt(hex, 16));
  });
""";

WITH RankedArticles AS (
  SELECT 
    DATE(PARSE_TIMESTAMP('%Y%m%d%H%M%S', CAST(DATE AS STRING))) AS PublishDate,
    DocumentIdentifier AS URL,
    
    -- Application de la fonction de décodage sur le titre extrait de la page html.
    DecodeHtmlEntities(REGEXP_EXTRACT(Extras, r'<PAGE_TITLE>(.*?)</PAGE_TITLE>')) AS Title,
    
    -- Récuparation de la langue de l'article.
    CASE
      WHEN TranslationInfo LIKE '%srclc:fra%' THEN 'Français'
      WHEN TranslationInfo LIKE '%srclc:zho%' THEN 'Chinois'
      WHEN TranslationInfo LIKE '%srclc:ara%' THEN 'Arabe'
      ELSE 'Anglais' 
    END AS Langue,
    
    -- Échantillonnage aléatoire de 250 articles par langue.
    ROW_NUMBER() OVER(
      PARTITION BY CASE
        WHEN TranslationInfo LIKE '%srclc:fra%' THEN 'Français'
        WHEN TranslationInfo LIKE '%srclc:zho%' THEN 'Chinois'
        WHEN TranslationInfo LIKE '%srclc:ara%' THEN 'Arabe'
        ELSE 'Anglais' 
      END 
      ORDER BY RAND()
    ) AS row_num
  FROM 
    `gdelt-bq.gdeltv2.gkg_partitioned`
  WHERE 
    DATE(_PARTITIONTIME) BETWEEN "2026-02-28" AND "2026-05-28"
    AND Extras LIKE '%<PAGE_TITLE>%'
    AND (
      TranslationInfo IS NULL
      OR TranslationInfo LIKE '%srclc:fra%'
      OR TranslationInfo LIKE '%srclc:zho%'
      OR TranslationInfo LIKE '%srclc:ara%'
    ) -- mots clé que je cherche dans la base de données. La recherche est traduite dans toutes les langues.
    AND (
      LOWER(Extras) LIKE '%iran%' 
      OR LOWER(DocumentIdentifier) LIKE '%iran%'
    )
    AND (
      LOWER(Extras) LIKE '%war%' OR LOWER(Extras) LIKE '%guerre%' OR LOWER(Extras) LIKE '%strike%' OR LOWER(Extras) LIKE '%frappe%' OR LOWER(Extras) LIKE '%conflict%' OR LOWER(Extras) LIKE '%israel%' OR LOWER(Extras) LIKE '%us%' OR LOWER(Extras) LIKE '%usa%'
    )
)
SELECT 
  PublishDate,
  URL,
  Title,
  Langue
FROM 
  RankedArticles
WHERE 
  row_num <= 250
ORDER BY 
  Langue, PublishDate;