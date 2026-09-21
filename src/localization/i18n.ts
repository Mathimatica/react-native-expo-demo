import { getLocales } from 'expo-localization';
import { I18n } from 'i18n-js';

import en from './translations/en';
import fr from './translations/fr';

const i18n = new I18n({
  en,
  fr,
});

i18n.locale = getLocales()[0].languageCode ?? 'en';
i18n.enableFallback = true;
i18n.defaultLocale = 'en';

export default i18n;
