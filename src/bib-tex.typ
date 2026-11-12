#import "bib-setting-function.typ": *
#import "bib-yomi.typ": *
#import "@preview/citegeist:0.3.1": load-bibliography

//---------- 文字列に日本語が含まれるかを判定する関数 ---------- //

#let check-japanese-tex-str(str) = {
  return (regex("[\p{scx:Han}\p{scx:Hira}\p{scx:Kana}]") in str)
}

//---------- 文献リストに日本語が含まれるかを判定する関数 ---------- //

#let check-japanese-tex(bibtex) = {
  return bibtex.values().any(val => check-japanese-tex-str(val))
}

//---------- 文献リストにlang要素を加える関数 ---------- //

#let add-dict-lang(biblist, lang) = {
  let output_list = biblist.fields
  let current_lang = output_list.at("lang", default: "")

  if current_lang != "en" and current_lang != "ja" {
    if lang == auto or (lang != "ja" and lang != "en") {
      if check-japanese-tex(biblist.fields) {
        output_list.insert("lang", "ja")
      } else {
        output_list.insert("lang", "en")
      }
    } else {
      output_list.insert("lang", lang)
    }
  }

  biblist.insert("fields", output_list)
  return biblist
}

//---------- BibLaTeX のフィールド名を BibTeX 名に解決する ---------- //
// Zotero の BibLaTeX 出力（journaltitle / date / location / eventtitle）を
// enja-bib が前提とする BibTeX 名（journal / year / address / booktitle）に寄せる。

#let biblatex-aliases = (
  journaltitle: "journal",
  location: "address",
  eventtitle: "booktitle",
)

// date（2000-04-15 / 2000-04 / 2000）から year を取り出す
// 既存の参考文献は年月を出していないため month は使わない
#let split-date(date) = {
  if type(date) != str or date == "" { return "" }
  date.split("-").at(0)
}

#let normalize-fields(biblist) = {
  let fields = biblist.fields

  // 別名フィールドを正規名へ移す（正規名が既にある場合は触らない）
  for (from, to) in biblatex-aliases.pairs() {
    if fields.at(from, default: "") != "" and fields.at(to, default: "") == "" {
      fields.insert(to, fields.at(from))
    }
  }

  // date → year（month は出力しない）
  if fields.at("year", default: "") == "" {
    let year = split-date(fields.at("date", default: ""))
    if year != "" { fields.insert("year", year) }
  }

  // eid（記事番号）は pages が無いときだけ pages として扱う
  if fields.at("pages", default: "") == "" and fields.at("eid", default: "") != "" {
    fields.insert("pages", fields.at("eid"))
  }

  // thesis 系は institution を school として表示する
  if biblist.entry_type in ("thesis", "mastersthesis", "phdthesis") {
    if fields.at("school", default: "") == "" and fields.at("institution", default: "") != "" {
      fields.insert("school", fields.at("institution"))
    }
  }

  // report 系は institution をそのまま使う（techreport の定義に合わせる）
  if biblist.entry_type == "report" {
    if fields.at("institution", default: "") == "" and fields.at("school", default: "") != "" {
      fields.insert("institution", fields.at("school"))
    }
  }

  biblist.insert("fields", fields)
  return biblist
}

//---------- 要素の関数を取得 ---------- //
#let get-element-function(style, biblist) = {
  return style.entry.at(biblist.entry_type, default: none).at(biblist.fields.lang, default: none)
}

//---------- LaTeX 表記を Typst に変換する ---------- //
// Zotero は数式を含むタイトルを LaTeX 記法で書き出すことがある。
// 実際の形は両端が \$ になる（Zotero が $ をエスケープするため）:
//   Pressure-Induced ... in \$\{\textbackslash text\{CuIr\}\}_{2}...\$
// 手で書いた場合は $...$ のこともある。どちらも受ける。

// LaTeX のコマンド → Typst の数式表記。
// 追加したいときはこの辞書に 1 行足すだけでよい。
// 値が "" のものは中身をそのまま置く（\mathrm{abc} → abc）。
// 値が "text" のものは数式内の文字列にする（\text{CuIr} → "CuIr"）。
//   Typst の数式では {CuIr} がコードブロック扱いになり落ちるため。
#let latex-commands = (
  "text": "text",
  "textrm": "text",
  "textit": "text",
  "textbf": "text",
  "mathrm": "text",
  "mathit": "text",
  "mathbf": "bold",
  "mathsf": "text",
  "mathtt": "text",
  "operatorname": "text",
  "alpha": "alpha",
  "beta": "beta",
  "gamma": "gamma",
  "delta": "delta",
  "epsilon": "epsilon",
  "varepsilon": "epsilon.alt",
  "zeta": "zeta",
  "eta": "eta",
  "theta": "theta",
  "kappa": "kappa",
  "lambda": "lambda",
  "mu": "mu",
  "nu": "nu",
  "xi": "xi",
  "rho": "rho",
  "sigma": "sigma",
  "tau": "tau",
  "phi": "phi",
  "varphi": "phi.alt",
  "chi": "chi",
  "psi": "psi",
  "omega": "omega",
  "Gamma": "Gamma",
  "Delta": "Delta",
  "Theta": "Theta",
  "Lambda": "Lambda",
  "Sigma": "Sigma",
  "Phi": "Phi",
  "Psi": "Psi",
  "Omega": "Omega",
  "times": "times",
  "pm": "plus.minus",
  "mp": "minus.plus",
  "approx": "approx",
  "sim": "tilde.op",
  "simeq": "tilde.eq",
  "leq": "<=",
  "le": "<=",
  "geq": ">=",
  "ge": ">=",
  "neq": "!=",
  "ne": "!=",
  "infty": "infinity",
  "cdot": "dot.op",
  "cdots": "dots.c",
  "ldots": "dots",
  "circ": "circle.stroked.tiny",
  "angstrom": "angstrom",
  "degree": "degree",
  "hbar": "planck.reduce",
  "partial": "diff",
  "nabla": "nabla",
)

// 名前の長い順に並べる（\text が \t に食われないように）
#let sorted-latex-names = {
  let out = ()
  let rest = latex-commands.keys()
  while rest.len() > 0 {
    let longest = rest.at(0)
    for n in rest {
      if n.len() > longest.len() { longest = n }
    }
    out.push(longest)
    rest = rest.filter(n => n != longest)
  }
  out
}

// 1 つの数式（$ を除いた中身）を Typst の数式文字列にする。
#let latex-math-to-typst(body) = {
  let s = body

  // Zotero の二重エスケープを 1 段戻す（\textbackslash text\{CuIr\} → \text{CuIr}）
  s = s.replace("\\textbackslash ", "\\")
  s = s.replace("\\{", "{")
  s = s.replace("\\}", "}")
  s = s.replace("\\_", "_")

  // \command{arg}
  for name in sorted-latex-names {
    let repl = latex-commands.at(name)
    let pat = regex("\\\\" + name + "\{([^{}]*)\}")
    while s.match(pat) != none {
      s = s.replace(pat, m => {
        let inner = m.captures.at(0)
        if repl == "text" {
          "\"" + inner + "\""
        } else if repl == "" {
          inner
        } else {
          repl + "(" + inner + ")"
        }
      })
    }
  }

  // 引数なしの \command（後ろが英字でないもの）
  for name in sorted-latex-names {
    let repl = latex-commands.at(name)
    let pat = regex("\\\\" + name + "([^a-zA-Z]|$)")
    s = s.replace(pat, m => repl + m.captures.at(0))
  }

  // 残った \{ \} \_ を処理
  s = s.replace("\\{", "{")
  s = s.replace("\\}", "}")
  s = s.replace("\\_", "_")

  // Typst の数式では { } がコードブロック扱いになるため取り除く。
  // 下付き・上付きの _ ^ はそのまま活かす。
  s = s.replace("{", "")
  s = s.replace("}", "")

  s.trim()
}

// codepoints のインデックスをバイト位置に変換する
#let cp-to-byte(text, cp-index) = {
  let cps = text.codepoints()
  let n = if cp-index > cps.len() { cps.len() } else { cp-index }
  let out = 0
  for i in range(n) {
    out += cps.at(i).len()
  }
  out
}

// 数式の区切りを探す。text は「$ が素の状態」の文字列を渡すこと。
// 日本語を含むので codepoints 単位で走査する（at(i) は文字境界で落ちる）。
#let math-spans(text) = {
  let spans = ()
  let cps = text.codepoints()
  let n = cps.len()
  let i = 0
  let start = -1
  while i < n {
    let c = cps.at(i)
    if c == "\\" {
      i += 2
      continue
    }
    if c == "$" {
      if start < 0 {
        start = i
      } else {
        spans.push((start: start, end: i + 1))
        start = -1
      }
    }
    i += 1
  }
  spans
}

// フィールド文字列の中の数式を Typst の数式に変換する。
// \$...\$ と $...$ の両方を受ける。
#let latex-to-typst(text) = {
  if type(text) != str { return text }

  // まず \$ を $ に戻す（Zotero のエスケープを解除）。
  let s = text.replace("\\$", "$")

  let spans = math-spans(s)
  if spans.len() == 0 { return text }

  let out = ""
  let pos = 0
  for sp in spans {
    let bstart = cp-to-byte(s, sp.start)
    let bend = cp-to-byte(s, sp.end)
    out += s.slice(pos, bstart)
    let body = s.slice(cp-to-byte(s, sp.start + 1), cp-to-byte(s, sp.end - 1))
    out += "$" + latex-math-to-typst(body) + "$"
    pos = bend
  }
  out + s.slice(pos)
}

//---------- eval に渡す前に markup の特殊文字を無害化する ---------- //
// 文献フィールドは eval(value, mode: "markup") で描画される。Zotero が
// タイトルへ LaTeX の数式や # @ < ] をそのまま書き出すと、それらが
// Typst の構文として解釈されてコンパイルが落ちる。
// 数式は Typst の数式に変換し、残りはエスケープした markup にする。
#let escape-markup(text) = {
  if type(text) != str { return text }
  let s = text
  s = s.replace("\\", "\\\\")
  s = s.replace("$", "\\$")
  s = s.replace("#", "\\#")
  s = s.replace("@", "\\@")
  s = s.replace("<", "\\<")
  s = s.replace("[", "\\[")
  s = s.replace("]", "\\]")
  s
}

// 文字列を安全に markup へ変換する
#let to-markup(value) = {
  if type(value) != str { return value }
  let converted = latex-to-typst(value)
  let spans = math-spans(converted)
  if spans.len() == 0 {
    return eval(escape-markup(converted), mode: "markup")
  }
  let out = ""
  let pos = 0
  for sp in spans {
    let bstart = cp-to-byte(converted, sp.start)
    let bend = cp-to-byte(converted, sp.end)
    out += eval(escape-markup(converted.slice(pos, bstart)), mode: "markup")
    out += eval(converted.slice(bstart, bend), mode: "markup")
    pos = bend
  }
  out += eval(escape-markup(converted.slice(pos)), mode: "markup")
  out
}

//---------- 文献リストを文献に変換 ---------- //
#let bibtex-to-bib(year-doubling, biblist, element_function) = {
  let output_list_bef = () //出力リスト(仮)
  let interval_str = "" //要素間の文字列
  let bef_element = "" //前の要素
  let element_num = 0 //要素の数
  let element_total_num = 0 //全要素数

  for bibitem in element_function {
    let tmp = biblist.fields.at(bibitem.at(0), default: "")
    if tmp != "" {
      //要素が存在する場合
      element_total_num += 1
    }
  }

  for bibitem in element_function {
    // 各要素に対して処理
    let tmp = biblist.fields.at(bibitem.at(0), default: none)
    if tmp != none and tmp != "" {
      // 要素が存在する場合
      element_num += 1

      //条件を満たすとき，前の要素間文字列を新しい文字列に置き換える
      if bibitem.at(1).at(5).contains(bef_element) and bibitem.at(1).at(0) != none {
        interval_str = bibitem.at(1).at(0)
      }
      //先頭に文字列を追加
      interval_str += bibitem.at(1).at(1)
      output_list_bef.push(interval_str)

      //要素を追加
      output_list_bef.push(bibitem.at(1).at(2)(biblist, bibitem.at(0)))

      //要素後に文字列を追加
      if element_num != element_total_num {
        //最後の要素でないとき
        output_list_bef.push(bibitem.at(1).at(3))
        interval_str = bibitem.at(1).at(4)
      } else {
        //最後の要素のとき
        output_list_bef.push(bibitem.at(1).at(6))
      }

      //前の要素を更新
      bef_element = bibitem.at(0)
    }
  }

  element_num = 0
  let bef_str = false //直前の要素が文字列かどうか
  let contain_str = ""
  let output_list = ()

  for value in output_list_bef {
    if value != "" {
      let outputvalue = value

      if bef_str or type(outputvalue) == str {
        if type(outputvalue) == str {
          contain_str += outputvalue
        } else {
          output_list.push(contain_str)
          output_list.push(outputvalue)
          contain_str = ""
        }
      } else {
        output_list.push(outputvalue)
      }

      if type(outputvalue) == str {
        bef_str = true
      } else {
        bef_str = false
      }
    }

    element_num += 1
  }

  if bef_str {
    output_list.push(contain_str)
    contain_str = ""
  }

  let outputlist = ()
  output_list_bef = ()
  for value in output_list {
    if type(value) == str {
      let tmp = value.split(year-doubling)
      if tmp.len() == 1 {
        output_list_bef.push(to-markup(value))
      } else {
        output_list_bef.push(to-markup(tmp.at(0)))
        outputlist.push(output_list_bef)
        output_list_bef = ()
        output_list_bef.push(to-markup(tmp.at(1)))
      }
    } else {
      output_list_bef.push(value)
    }
  }
  outputlist.push(output_list_bef)

  return outputlist
}

//---------- citeを作成する関数 ---------- //
#let bibtex-to-cite(
  bib-cite-author,
  bib-cite-year,
  biblist,
) = {
  let cite_list = ()

  //citet
  cite_list.push(bib-cite-author(biblist, "author"))
  //citep
  cite_list.push(bib-cite-year(biblist, "year"))

  return cite_list
}

//---------- 並び替えのための読み仮名 ---------- //
#let bibtex-yomi(biblist, bib_arr) = {
  let bib_str = contents-to-str(bib_arr.sum().sum())
  let yomi = biblist.fields.at("yomi", default: "")
  if yomi == "" {
    yomi = auto-make-yomi(biblist, bib_str)
  }

  if type(yomi) == content {
    yomi = contents-to-str(yomi)
  }

  if check-japanese-tex-str(yomi){
    yomi = romaji(yomi)
  }

  yomi = yomi.replace("{", "")
  yomi = yomi.replace("}", "")
  yomi = lower(yomi)

  return yomi
}
