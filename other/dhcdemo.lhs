= DHC Demo =

The following compiles Haskell to WebAssembly and runs it.

Only a tiny fragment of the language is supported. There is almost no syntax
sugar.

System calls:

------------------------------------------------------------------------------
putStr :: String -> IO ()
putInt :: Int -> IO ()
------------------------------------------------------------------------------

There is no garbage collection.

https://github.com/dfinity/dhc[Source].

[pass]
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
<script type="text/javascript">
var dv;
function load8(addr) { return dv.getUint8(addr); }
function runWasmInts(a){WebAssembly.instantiate(new Uint8Array(a),
{system:{putInt:(lo,hi) => { Haste.sysPutInt(lo,hi); },
putStr:(a,n) => { Haste.sysPutStr(a,n) } }}).then(x => {
expo = x.instance.exports;
dv = new DataView(expo.memory.buffer);
document.getElementById('out').innerHTML ="";
expo['main']()});
}

function downloadWasm(arr) {
  var blob = new Blob([new Uint8Array(arr)], {type: "application/octet-stream"});
  var a = document.createElement('a');
  a.style.display = 'none';
  document.body.append(a);
  var url = URL.createObjectURL(blob);
  a.href = url;
  a.download = "a.wasm";
  a.click();
  URL.revokeObjectURL(url);
}
</script>
<script src="dhcdemo.js">
</script>
<p><textarea id="src" rows="25" cols="80">
include::test/demo.hs[]
</textarea></p>
<button id="go">Compile & Run!</button>
<button id="get">Download</button>
<p><textarea id="asm" readonly rows="5" cols="80">
</textarea></p>
<pre id="out"></pre>
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//////////////////////////////////////////////////////////////////////////////
\begin{code}
{-# LANGUAGE OverloadedStrings #-}
import Control.Monad
import Data.Char
import Haste.DOM
import Haste.Events
import Haste.Foreign
import Asm
import Demo

append :: Elem -> String -> IO ()
append e s = do
  v <- getProp e "innerHTML"
  setProp e "innerHTML" $ v ++ s

sysPutStr :: Elem -> Int -> Int -> IO ()
sysPutStr e a n = append e =<< mapM (fmap chr . load8 . (a +)) [0..n - 1]
  where load8 = ffi "load8" :: Int -> IO Int

sysPutInt :: Elem -> Int -> Int -> IO ()
sysPutInt e y x = append e $ case x of
  0 -> show y ++ if y >= 0 then "" else
    " (unsigned = " ++ show (fromIntegral y + b) ++ ")"
  _ -> show $ fromIntegral x * b + ((fromIntegral y + b) `mod` b)
  where b = 2^(32 :: Int) :: Integer

main :: IO ()
main = withElems ["src", "asm", "go", "get", "out"] $ \[src, asmEl, goB, getB, outE] -> do
  export "sysPutStr" $ sysPutStr outE
  export "sysPutInt" $ sysPutInt outE
  let
    go f = do
      setProp asmEl "value" ""
      s <- ("public (main)\n" ++) <$> getProp src "value"
      case hsToWasm jsDemoBoost s of
        Left err -> setProp asmEl "value" err
        Right asm -> do
          setProp asmEl "value" $ show asm
          f asm
  void $ goB `onEvent` Click $ const $ go $ ffi "runWasmInts"
  void $ getB `onEvent` Click $ const $ go $ ffi "downloadWasm"

\end{code}
//////////////////////////////////////////////////////////////////////////////
