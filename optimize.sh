#!/bin/bash

TEMP_DIR=temp
INPUT_DIR=src
OUTPUT_DIR=out

WIDTH=0
HEIGHT=300
IMAGE_QUALITY=100

while getopts "i:o:w:h:q:" opt; do
  case ${opt} in
    i )
      INPUT_DIR=$OPTARG
      ;;
    o )
      OUTPUT_DIR=$OPTARG
      ;;
    w )
      WIDTH=$OPTARG
      ;;
    h )
      HEIGHT=$OPTARG
      ;;
    q )
      IMAGE_QUALITY=$OPTARG
      ;;
    \? )
      echo "Usage: ./optimize.sh [-i input_dir] [-o output_dir] [-w width] [-h height] [-q image_quality]"
      exit 1
      ;;
  esac
done

rm -rf "$TEMP_DIR"
mkdir -p "$OUTPUT_DIR"

mkdir "$TEMP_DIR"
cp -r "$INPUT_DIR"/* "$TEMP_DIR"

optimize_image() {
  local input_file="$1"
  local output_file="$2"
  cwebp -q "$IMAGE_QUALITY" -m 6 -sharpness 0 -noalpha -resize "$WIDTH" "$HEIGHT" -quiet "$input_file" -o "$output_file"
}

convert_svg_to_webp() {
  local input_file="$1"
  local output_file="$2"
  local temp_png="${output_file}.png"
  rsvg-convert -o "$temp_png" "$input_file"
  optimize_image "$temp_png" "$output_file"
  rm "$temp_png"
}

optimize_webp() {
    local input_file="$1"
    local output_file="$2"
    local temp_output="${output_file}.temp"

    if webpmux -info "$input_file" 2>&1 | grep -q "No. of frames: 1"; then
        optimize_image "$input_file" "$temp_output"
    else
        gif2webp -q "$IMAGE_QUALITY" "$input_file" -o "$temp_output"
    fi

    local original_size=$(stat -c %s "$input_file")
    local new_size=$(stat -c %s "$temp_output")

    if (( new_size < original_size )); then
      mv "$temp_output" "$output_file"
      echo "Optimized: $input_file -> $output_file (reduced size from $original_size to $new_size)"
    else
      rm "$temp_output"
      cp "$input_file" "$output_file"
      echo "Copied without change: $input_file -> $output_file"
    fi
}

file_exists_in_output() {
  local input_file="$1"
  local filename=$(basename "$input_file")
  [ -f "$OUTPUT_DIR/$filename" ]
}

process_images() {
  for img in "$TEMP_DIR"/*.{jpg,jpeg,png}; do
    [ -f "$img" ] || continue
    filename=$(basename "$img" .${img##*.})
    output_file="$OUTPUT_DIR/$filename.webp"
    if ! file_exists_in_output "$output_file"; then
      optimize_image "$img" "$output_file"
      echo "Converted: $img -> $output_file"
    fi
  done
}

process_svgs() {
  for svg in "$TEMP_DIR"/*.svg; do
    [ -f "$svg" ] || continue
    filename=$(basename "$svg" .svg)
    output_file="$OUTPUT_DIR/$filename.webp"
    if ! file_exists_in_output "$output_file"; then
      convert_svg_to_webp "$svg" "$output_file"
      echo "Converted: $svg -> $output_file"
    fi
  done
}

process_webps() {
  for webp in "$TEMP_DIR"/*.webp; do
    [ -f "$webp" ] || continue
    filename=$(basename "$webp" .webp)
    output_file="$OUTPUT_DIR/$filename.webp"
    if ! file_exists_in_output "$output_file"; then
      optimize_webp "$webp" "$output_file"
    fi
  done
}

process_images
process_svgs
process_webps

find "$TEMP_DIR" -type f ! -name '*.jpg' ! -name '*.jpeg' ! -name '*.png' ! -name '*.svg' -exec cp -v {} "$OUTPUT_DIR/" \;

files_count=$(find "$INPUT_DIR" -type f | wc -l)
echo "$files_count files in $INPUT_DIR"

total=$(find "$OUTPUT_DIR" -type f | wc -l)
echo "Total: $total files in $OUTPUT_DIR"

rm -rf "$TEMP_DIR"

echo "Optimization completed."
