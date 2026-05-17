const fs = require('fs');
const path = require('path');

const rootDir = 'd:\\Internship\\Atkool as Agents folder\\atkool-fultter-app';
const oldPackage = 'com.schoolconnect.school_connect';
const newPackage = 'com.atkool.school';

// Replace in build.gradle.kts
const gradlePath = path.join(rootDir, 'android/app/build.gradle.kts');
if (fs.existsSync(gradlePath)) {
  let content = fs.readFileSync(gradlePath, 'utf8');
  content = content.replace(new RegExp(oldPackage, 'g'), newPackage);
  fs.writeFileSync(gradlePath, content, 'utf8');
}

// Replace in AndroidManifests
const manifestPaths = [
  'android/app/src/main/AndroidManifest.xml',
  'android/app/src/debug/AndroidManifest.xml',
  'android/app/src/profile/AndroidManifest.xml'
];

for (const mPath of manifestPaths) {
  const fullPath = path.join(rootDir, mPath);
  if (fs.existsSync(fullPath)) {
    let content = fs.readFileSync(fullPath, 'utf8');
    content = content.replace(new RegExp(oldPackage, 'g'), newPackage);
    fs.writeFileSync(fullPath, content, 'utf8');
  }
}

// Move MainActivity.kt and update its content
const oldMainPath = path.join(rootDir, 'android/app/src/main/kotlin/com/schoolconnect/school_connect/MainActivity.kt');
const newMainDir = path.join(rootDir, 'android/app/src/main/kotlin/com/atkool/school');
const newMainPath = path.join(newMainDir, 'MainActivity.kt');

if (fs.existsSync(oldMainPath)) {
  fs.mkdirSync(newMainDir, { recursive: true });
  let content = fs.readFileSync(oldMainPath, 'utf8');
  content = content.replace(`package ${oldPackage}`, `package ${newPackage}`);
  fs.writeFileSync(newMainPath, content, 'utf8');
  fs.unlinkSync(oldMainPath);
}

console.log('Package renamed successfully to ' + newPackage);
