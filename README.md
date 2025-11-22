# Rugburn

Rugburn is a lightweight macOS utility that slides out a web panel when your mouse hits the right edge of the screen — inspired by the convenience of Slidepad, but built from scratch as a fully open-source project.

V0.9 Beta

---

## 🚀 Features

- Slide-out web panel triggered by moving the cursor to the right edge  
- Automatically hides when not in use  
- Fast, simple, and minimal  
- 100% open source — built in Swift  
- Easy foundation for adding extensions or customization

---

## 📦 Installation

1. Clone the repository:

       git clone https://github.com/Cyberpunk69420/Rugburn.git

2. Open `Rugburn.xcodeproj` in Xcode.

3. Build and run the project.

---

## 🧪 Usage

- Move your mouse cursor to the **right edge of the screen** to reveal the web panel.  
- Move the cursor away to hide it.  
- Customize the default URL or expand functionality by editing the code.

---

## 🧩 Current Limitations

- Limited to a single panel  
- No persistent preferences yet  
- Multi-monitor support may need refinement  

These can be improved in future releases — contributions welcome!

---

## 🤝 Contributing

Pull requests, ideas, and improvements are encouraged.

- Open an Issue to report bugs  
- Submit PRs with enhancements  
- Suggest features you'd like to see

---

## 📜 License

Rugburn is released under the **MIT License**.  
See the `LICENSE` file for full details.

---

## 🐛 Remaining Bugs

- The hotkey toggle button remains blue even when disabled
- User Agent switcher (mobile request to desktop request) Does not always request a new page reload, and if mobile url is the current url (ie m.youtube.com), the page must be reloaded or renavigated to to update the UA.
- Some issue with Webcrypto master key requests from keychain (need to implement friendly view?)
- Some streaming sites do not want to stream music or video audio when the panel is hidden, depending on User Agent of the page
  - ie music.youtube.com will continue to stream music on hidden panel of desktop user agent is current instead of mobile
- Help hovertext doesn't always show depending on app focus
- sometimes rarely the favicon downloader for bookmarks fails, seems like some sites (microsoft.com) do not keep their favicons in the standard location or format

--- 

## ✨ Author

Created by [Cyberpunk69420](https://github.com/Cyberpunk69420)

Inspired by Slide*pad — but entirely independently implemented. 

Vibecoded with love and mild autism
-John
