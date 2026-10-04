import Foundation
let oldURL=URL(fileURLWithPath:"docs/native-validation/artifacts/2026-10-02-black-gamma/reference-before-bit-preservation.json")
let newURL=URL(fileURLWithPath:"tests/fixtures/native-contracts/black-gamma-legacy-reference.json")
let old=try JSONSerialization.jsonObject(with:Data(contentsOf:oldURL)) as! [String:Any]
let new=try JSONSerialization.jsonObject(with:Data(contentsOf:newURL)) as! [String:Any]
var mismatches:[[String:Any]]=[]
for (index,pair) in zip(old["cases"] as! [[String:Any]],new["cases"] as! [[String:Any]]).enumerated(){
    let before=pair.0["anchors"] as! [Double],after=(pair.1["anchors"] as! [String]).map{Double($0)!}
    for c in 0..<3 where before[c].bitPattern != after[c].bitPattern {
        mismatches.append(["case":index,"field":"anchor[\(c)]","numeric":String(before[c]),"exactString":String(after[c]),"numericBits":String(before[c].bitPattern,radix:16),"exactBits":String(after[c].bitPattern,radix:16)])
    }
}
let data=try JSONSerialization.data(withJSONObject:["mismatches":mismatches],options:[.prettyPrinted,.sortedKeys])
print(String(decoding:data,as:UTF8.self))
