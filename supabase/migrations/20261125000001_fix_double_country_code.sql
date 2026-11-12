-- Edit Profile used to save "+234" + an already-prefixed number, so some accounts ended up with the country code
-- inside contact_number (phone login then failed). Strip it. (Applied by hand for the one affected account.)
update app.users set contact_number = ltrim(substr(regexp_replace(contact_number, '\D', '', 'g'), length(regexp_replace(country_code, '\D', '', 'g')) + 1), '0')
 where contact_number is not null and regexp_replace(coalesce(country_code, ''), '\D', '', 'g') <> ''
   and regexp_replace(contact_number, '\D', '', 'g') like regexp_replace(country_code, '\D', '', 'g') || '%'
   and length(regexp_replace(contact_number, '\D', '', 'g')) - length(regexp_replace(country_code, '\D', '', 'g')) >= 8;
