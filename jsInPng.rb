# coding: UTF-8
require "zlib"
require "RMagick"
include Magick

if ARGV[0].nil? || ARGV[1].nil? then
  puts "error."
  exit
end

img = ImageList.new(ARGV[1])
width = img.columns
height = img.rows

js_text = File.open(ARGV[0]).read
js_size = js_text.bytesize

if js_size > (width * height * 3 / 4) then
  puts "error."
  exit
end

depth, color_type = 8, 2

# グラデーションのベタデータ
cnt = 0
raw_data = []

for y in 0...height do
  w_color = []
  for x in 0...width do
    src = img.pixel_color(x, y)
    color = [src.red, src.green, src.blue]

    for i in 0...color.size do
      char = (js_text.length > cnt/4) ? js_text[cnt/4].ord : 0x00
      bits = ((char << (cnt%4 * 2)) % 256) >> 6
      color[i] = ((color[i] >> 2) << 2) | bits
      cnt += 1
    end

    w_color.push(color.clone)
  end
  raw_data.push(w_color.flatten)
end

# チャンクのバイト列生成関数
def chunk(type, data)
  [data.bytesize, type, data, Zlib.crc32(type + data)].pack("NA4A*N")
end

# ファイルシグニチャ
print "\x89PNG\r\n\x1a\n"

# ヘッダ
print chunk("IHDR", [width, height, 8, 2, 0, 0, 0].pack("NNCCCCC"))

print chunk("tEXT", "<meta charset='utf-8'/>")
print chunk("tEXT", "<script>/*")
print chunk("tEXT", <<'EOS')
*/
(function(){
  var body = document.body;
  var img = document.createElement('img');
  img.setAttribute('src', '#');
  img.addEventListener('load', function(){
    var canvas = document.createElement('canvas');
    body.appendChild(canvas);

    var width = canvas.width = img.width;
    var height = canvas.height = img.height;
    canvasCtx = canvas.getContext('2d');
    canvasCtx.drawImage(img, 0, 0);

    var data = canvasCtx.getImageData(0, 0, width, height).data;
    var char = 0; var cnt = 0;
    for(var idx = 0, code = '', byte; idx < data.length; idx += (idx % 4 == 2) ? 2 : 1) {
      byte = data[idx];
      char += parseInt(byte.toString(2).substr(-2), 2) << (2 * (3 - cnt % 4));
      if (cnt % 4 == 3) {
        if (char === 0) break;
        code += String.fromCharCode(char);
        char = 0;
      }
      cnt ++;
    }
    eval(code);
  });

  body.appendChild(img);
})();
/*
EOS
print chunk("tEXT", "*/</script>")

# 画像データ
img_data = raw_data.map {|line| ([0] + line.flatten).pack("C*") }.join
print chunk("IDAT", Zlib::Deflate.deflate(img_data))

# 終端
print chunk("IEND", "")
