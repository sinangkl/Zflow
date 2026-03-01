# 🎯 Swipe Actions - İşlem Düzenleme ve Silme

## 📋 Genel Bakış

Kullanıcılar artık işlemleri (transactions) sağa kaydırarak **Düzenle** ve **Sil** seçeneklerine erişebilirler. Her iki işlem de native iOS HIG standartlarına uygun şekilde uygulanmıştır.

## ✨ Yeni Özellikler

### 1. **Swipe Actions** (Kaydırma İşlemleri)
- ✅ İşlemi **sağa kaydır** → Düzenle ve Sil butonları görünür
- ✅ **Sil** butonu kırmızı, tehlikeli işlem olarak işaretli
- ✅ **Düzenle** butonu mavi (ZColor.indigo)
- ✅ `allowsFullSwipe: false` - Kazara silmeyi önler

### 2. **Context Menu** (Uzun Basma Menüsü)
- ✅ İşleme uzun bas → Aynı seçenekler menü olarak görünür
- ✅ Alternatif erişim yöntemi (accessibility için önemli)

### 3. **EditTransactionView** (Düzenleme Ekranı)
- ✅ Mevcut işlem verilerini gösterir
- ✅ Tüm alanları düzenlenebilir
- ✅ **Değişiklik algılama** - Sadece değişiklik varsa kaydet butonu aktif
- ✅ **İçinde silme butonu** - Düzenleme ekranından da silinebilir
- ✅ Modern, temiz UI
- ✅ Onay dialogları

### 4. **Silme Onayı** (Confirmation Dialog)
- ✅ Native iOS confirmation dialog
- ✅ "Bu işlem geri alınamaz" uyarısı
- ✅ İptal ve Sil seçenekleri
- ✅ Haptic feedback

## 📁 Güncellenen Dosyalar

### Yeni Dosya:
- ✅ **EditTransactionView.swift** - İşlem düzenleme ekranı

### Güncellenen Dosyalar:
- ✅ **CalendarView.swift** - Swipe actions eklendi
- ✅ **DashboardView.swift** - Swipe actions eklendi
- ✅ **TransactionsReportsView.swift** - Zaten vardı, optimize edildi
- ✅ **AllTransactionsView.swift** - Zaten vardı

## 🎨 UI/UX Detayları

### Swipe Actions

```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    // Sil - Kırmızı, destructive
    Button(role: .destructive) {
        transactionToDelete = txn
        Haptic.medium()
    } label: {
        Label("Sil", systemImage: "trash.fill")
    }
    
    // Düzenle - Mavi
    Button {
        transactionToEdit = txn
        Haptic.light()
    } label: {
        Label("Düzenle", systemImage: "pencil")
    }
    .tint(ZColor.indigo)
}
```

### Context Menu

```swift
.contextMenu {
    Button {
        transactionToEdit = txn
    } label: {
        Label("Düzenle", systemImage: "pencil")
    }
    
    Button(role: .destructive) {
        transactionToDelete = txn
    } label: {
        Label("Sil", systemImage: "trash")
    }
}
```

### Confirmation Dialog

```swift
.confirmationDialog(
    "Sil",
    isPresented: $showDeleteConfirm,
    titleVisibility: .visible
) {
    Button("Sil", role: .destructive) {
        deleteTransaction()
    }
    Button("İptal", role: .cancel) {}
} message: {
    Text("Bu işlem geri alınamaz.")
}
```

## 🎯 Kullanım Akışı

### Senaryo 1: Sağa Kaydırarak Sil

1. Kullanıcı işlemi **sağa kaydırır**
2. **Sil** ve **Düzenle** butonları görünür
3. **Sil**'e basar
4. Onay dialogu açılır: "Bu işlem geri alınamaz"
5. **Sil** → İşlem silindi, haptic feedback
6. **İptal** → Dialog kapanır

### Senaryo 2: Sağa Kaydırarak Düzenle

1. Kullanıcı işlemi **sağa kaydırır**
2. **Düzenle**'ye basar
3. **EditTransactionView** açılır
4. Mevcut bilgiler gösterilir
5. Kullanıcı değişiklik yapar
6. **Kaydet** → Güncellendi
7. **İptal** → Değişiklikler atıldı
8. **Sil** butonu (altta) → Onay ile silinir

### Senaryo 3: Uzun Basma (Context Menu)

1. Kullanıcı işleme **uzun basar**
2. Context menu açılır
3. **Düzenle** veya **Sil** seçer
4. Aynı akış devam eder

## 🎨 EditTransactionView Özellikleri

### Akıllı Değişiklik Algılama

```swift
private var hasChanges: Bool {
    guard let amt = Double(amount.replacingOccurrences(of: ",", with: ".")) 
    else { return false }
    
    return amt != transaction.amount ||
        selectedCurrency.rawValue != transaction.currency ||
        selectedType.rawValue != (transaction.type ?? "expense") ||
        selectedCategory?.id != transaction.categoryId ||
        note != (transaction.note ?? "") ||
        !Calendar.current.isDate(date, inSameDayAs: transaction.date ?? Date())
}
```

- Herhangi bir alan değiştirildiğinde **Kaydet** butonu aktif olur
- Değişiklik yoksa buton devre dışı (gri)
- Gereksiz güncelleme yapılmasını önler

### İki Kaydetme Butonu

1. **Üstteki Kaydet** (büyük, gradient)
   - Ana kaydetme butonu
   - Değişiklik yoksa disabled
   - Gradient renk (gelir/gider)

2. **Alttaki Sil** (küçük, gri arka plan)
   - Tehlikeli işlem
   - Confirmation dialog açar
   - Kırmızı metin

## 🔄 ViewModel Metodları

### Güncelleme

```swift
func updateTransaction(
    id: UUID,
    userId: UUID,
    amount: Double,
    currency: Currency,
    type: TransactionType,
    categoryId: UUID?,
    note: String?,
    date: Date
) async
```

### Silme

```swift
func deleteTransaction(id: UUID, userId: UUID) async
```

## 🎵 Haptic Feedback

- **Düzenle butonu**: `.light()` - Hafif, bilgilendirici
- **Sil butonu**: `.medium()` - Orta, dikkat çekici
- **Başarılı işlem**: `.success()` - Onaylayıcı
- **Seçim**: `.selection()` - Standart seçim

## 🌍 Lokalizasyon

Tüm metinler NSLocalizedString ile çevrilebilir:

```swift
"common.edit" = "Düzenle" / "Edit"
"common.delete" = "Sil" / "Delete"
"common.cancel" = "İptal" / "Cancel"
"common.save" = "Kaydet" / "Save Changes"
"common.deleteWarning" = "Bu işlem geri alınamaz." / "This action cannot be undone."
"transaction.amount" = "Tutar" / "Amount"
"transaction.currency" = "Para Birimi" / "Currency"
"transaction.category" = "Kategori" / "Category"
"transaction.date" = "Tarih" / "Date"
"transaction.note" = "Not (Opsiyonel)" / "Note (optional)"
```

## ♿ Accessibility

- ✅ **Context Menu**: Swipe yapamayan kullanıcılar için
- ✅ **VoiceOver**: Tüm butonlar label ile tanımlı
- ✅ **Dynamic Type**: Text boyutları ölçeklenir
- ✅ **Confirmation Dialogs**: Kazara silmeyi önler

## 🧪 Test Senaryoları

### 1. Swipe Action - Sil
- [ ] İşlemi sağa kaydır
- [ ] Sil butonuna bas
- [ ] Onay dialogunu görüntüle
- [ ] Sil'e bas → İşlem silindi mi?
- [ ] İptal'e bas → İşlem durduğu yerde mi?

### 2. Swipe Action - Düzenle
- [ ] İşlemi sağa kaydır
- [ ] Düzenle butonuna bas
- [ ] EditTransactionView açıldı mı?
- [ ] Mevcut veriler doğru mu?
- [ ] Değişiklik yap → Kaydet aktif mi?
- [ ] Kaydet → Güncellendi mi?

### 3. Context Menu
- [ ] İşleme uzun bas
- [ ] Menu açıldı mı?
- [ ] Düzenle ve Sil seçenekleri var mı?
- [ ] Her ikisi de çalışıyor mu?

### 4. EditTransactionView - Değişiklik Algılama
- [ ] Hiç değişiklik yapma → Kaydet disabled mı?
- [ ] Sadece tutarı değiştir → Kaydet aktif mi?
- [ ] Kategoriyi değiştir → Kaydet aktif mi?
- [ ] Orijinal değerlere dön → Kaydet disabled mı?

### 5. EditTransactionView - Silme
- [ ] Alttaki Sil butonuna bas
- [ ] Confirmation dialog açıldı mı?
- [ ] Sil → İşlem silindi ve ekran kapandı mı?
- [ ] İptal → Dialog kapandı, işlem durduğu yerde mi?

### 6. Haptic Feedback
- [ ] Düzenle → Light haptic
- [ ] Sil → Medium haptic
- [ ] Başarılı işlem → Success haptic

### 7. Çoklu Konum
- [ ] **DashboardView** → Recent Transactions
- [ ] **CalendarView** → Selected Day Transactions
- [ ] **TransactionsReportsView** → Transaction List
- [ ] **AllTransactionsView** → Full List

## 🚀 Gelecek Geliştirmeler

- [ ] Toplu silme (multiple selection)
- [ ] Geri al (undo) özelliği
- [ ] Çoğalt (duplicate) butonu
- [ ] Hızlı kategori değiştirme (quick actions)
- [ ] Sürükle-bırak ile sıralama
- [ ] Favorilere ekle

## 📝 Notlar

- Swipe actions yalnızca **sağa kaydırmada** çalışır (trailing edge)
- Full swipe **kapalı** - Kazara silmeyi önler
- Tüm silme işlemleri **confirmation dialog** ile onaylanır
- EditTransactionView **modal** olarak açılır
- Değişiklik algılama **gerçek zamanlı** çalışır
- Tüm işlemler **async/await** ile yapılır
- Haptic feedback her yerde **tutarlı**

## 🎉 Sonuç

Kullanıcılar artık işlemlerini çok daha kolay düzenleyebilir ve silebilir! iOS native davranışlarına uygun, kullanıcı dostu bir deneyim sunuldu.
