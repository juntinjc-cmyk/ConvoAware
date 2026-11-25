# 對話感知 v0.1（iPhone App）

AirPods 播音樂，iPhone 麥克風聽周圍；偵測到有人說話時，音樂緩降，講完再緩升。
聲音只在手機上即時分析，不錄存、不上傳。

全程不需要 Mac：GitHub 雲端編譯 → Windows 用 Sideloadly 裝到 iPhone。

---

## 第一步：把程式放上 GitHub

1. 到 https://github.com 註冊帳號。
2. 右上角「+」→「New repository」。
   - Repository name：`ConvoAware`
   - 選 **Public**（公開的專案雲端編譯免費且不限時數；程式碼裡沒有任何密碼或個人資料）
   - 其他都不用勾，按「Create repository」。
3. 在新專案頁面點「uploading an existing file」。
4. 把這個資料夾**裡面的所有東西**（`ConvoAware` 資料夾、`.github` 資料夾、`project.yml`、`README.md`）一起拖進網頁。
   - `.github` 資料夾一定要傳，雲端編譯的設定在裡面。
5. 按下方綠色「Commit changes」。

## 第二步：等雲端編譯

1. 點專案上方的「Actions」分頁。
2. 會看到「編譯 iPhone App」正在跑（黃色圓圈），大約 5～10 分鐘。
3. 變成綠色勾勾就成功了。點進去，最下面「Artifacts」有 `ConvoAware-ipa`，點它下載。
4. 解壓縮，得到 `ConvoAware.ipa`。

**變成紅色叉叉？** 點進去截圖錯誤訊息給 Claude，我會修好程式，你再上傳一次。

## 第三步：在 iPhone 打開開發者模式

1. iPhone「設定 > 隱私權與安全性 > 開發者模式」打開，手機會重新開機。
   - 如果找不到這個選項，先做完第四步，裝過一次 App 之後就會出現。

## 第四步：用 Sideloadly 安裝（Windows）

1. 從 Apple 官網安裝 **iTunes** 和 **iCloud**（Sideloadly 需要它們的驅動程式；不要用 Microsoft Store 版本）。
2. 到 https://sideloadly.io 下載並安裝 Sideloadly。
3. 用 USB 線把 iPhone 接到電腦，iPhone 上按「信任這部電腦」。
4. 打開 Sideloadly：
   - 把 `ConvoAware.ipa` 拖進視窗
   - 輸入你的 Apple ID（建議用一個備用 Apple ID）
   - 按「Start」，需要時在跳出的視窗輸入 Apple ID 密碼
5. iPhone「設定 > 一般 > VPN 與裝置管理」，點你的 Apple ID，按「信任」。
6. 免費 Apple ID 裝的 App **7 天後會失效**，重做第四步就好。

## 第五步：開始測試

1. 把一首 mp3 或 m4a 放進 iPhone 的「檔案」App（例如 iCloud Drive）。
2. 戴上 AirPods，打開「對話感知」。
3. 按「選擇音樂檔」→ 選那首歌 → 按「播放」。
4. 按「開始監聽」，允許麥克風權限。
5. 請朋友在旁邊跟你說話，看音樂會不會壓低、講完會不會升回。
6. 螢幕鎖定後也會繼續運作。

### 測試時記下這些

- 朋友叫你 10 次，成功觸發幾次？
- 安靜放著 10 分鐘，誤觸發幾次？是被什麼聲音觸發的（看「紀錄」）？
- 從對方開口到音樂壓低，大概多久？

### 可以調的參數

| 參數 | 調高 | 調低 |
| --- | --- | --- |
| 觸發門檻 | 比較不會誤觸發，但可能漏掉 | 比較敏感 |
| 最小音量 | 只有近距離說話才觸發 | 遠處的人聲也會觸發 |
| 講完後等多久 | 對話中停頓不會升回 | 講完很快升回 |
| 壓低到原本的 | 音樂壓得少 | 音樂壓得多 |

## 已知限制（v0.1）

- 收音用 iPhone 麥克風，放口袋會比較悶，建議拿在手上或放胸前口袋測試。
- 分辨不出是你自己還是別人在說話，你自己開口也會觸發。
- 無法判斷聲音方向（需要耳機上的多顆麥克風）。
- 只能壓低這個 App 自己播的音樂，Spotify、Apple Music 等其他 App 還不行。
- 人聲辨識用 Apple 內建的聲音分類，反應時間大約 0.5～1 秒。
