import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';
import type { Cat } from './src/models/Cat';
import i18n from './src/localization/i18n';

const cat: Cat = {
  id: 'british-shorthair',
  name: 'British Shorthair',
  origin: 'United Kingdom',
  imageUrl: 'https://cdn2.thecatapi.com/images/0XYvRd7oD.jpg',
};

export default function App() {
  return (
    <View style={styles.container}>
      <Text style={styles.title}>{i18n.t('catBrowser.title')}</Text>
      <Text>{cat.name}</Text>
      <Text>{cat.origin}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 24,
  },
});
