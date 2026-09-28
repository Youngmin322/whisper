"""Build the emotion flame SVG concepts from simple, editable paths."""

from pathlib import Path

ROOT = Path(__file__).parent

FLAMES = {
    "anxiety": {
        "name": "불안",
        "outer": "#AA91CC",
        "inner": "#E5D4F2",
        "body": "M115 13 C89 21 80 42 82 59 C80 75 66 87 53 104 C31 125 13 155 13 184 C14 214 36 239 63 248 C88 257 125 254 148 236 C180 216 191 177 177 143 C163 113 140 94 116 75 C94 58 96 40 115 13 Z",
        "core": "M93 84 C82 103 63 119 49 143 C36 165 36 188 49 208 C61 226 88 234 111 226 C135 218 146 194 141 172 C136 148 116 124 101 104 C97 98 94 91 93 84 Z",
        "face": '<ellipse cx="67" cy="166" rx="6" ry="8"/><ellipse cx="113" cy="160" rx="6" ry="8"/><path d="M60 155 Q68 151 76 145 M104 143 Q112 146 119 151" fill="none" stroke-width="5" stroke-linecap="round"/><path d="M73 195 Q80 190 87 196 Q96 202 105 195" fill="none" stroke-width="5.5" stroke-linecap="round"/>',
    },
    "depression": {
        "name": "우울",
        "outer": "#8391B7",
        "inner": "#CCD5E9",
        "body": "M95 43 C75 60 74 78 57 101 C36 124 22 144 13 169 C2 199 19 226 45 240 C69 254 116 256 145 241 C170 229 183 203 179 174 C176 150 154 124 139 111 C126 99 116 86 110 69 C118 74 126 75 134 73 C122 65 109 46 95 43 Z",
        "core": "M94 108 C83 125 65 136 52 155 C39 172 39 196 52 214 C65 230 91 234 113 226 C134 219 144 201 140 183 C135 162 116 146 102 128 C98 120 96 113 94 108 Z",
        "face": '<path d="M60 179 L80 175 C78 193 61 196 60 179 Z M104 175 L124 179 C123 196 106 193 104 175 Z" stroke="none"/><path d="M77 207 Q91 200 105 207" fill="none" stroke-width="5.5" stroke-linecap="round"/>',
    },
    "anger": {
        "name": "분노",
        "outer": "#EB765E",
        "inner": "#FFCBA5",
        "body": "M92 7 C86 31 84 49 69 70 C54 91 34 105 22 129 C6 157 1 193 18 222 C35 249 69 255 98 253 C132 252 164 237 178 207 C190 181 178 157 165 138 C169 151 162 158 151 155 C145 132 137 109 118 83 C105 63 94 39 92 7 Z",
        "core": "M91 86 C80 106 64 120 51 142 C38 165 40 192 54 210 C68 228 96 231 116 220 C135 211 146 192 141 170 C136 145 113 123 99 102 C95 96 93 91 91 86 Z",
        "face": '<path d="M61 157 L78 164 M119 157 L103 164" fill="none" stroke-width="6" stroke-linecap="round"/><ellipse cx="70" cy="174" rx="5.5" ry="6.5"/><ellipse cx="110" cy="174" rx="5.5" ry="6.5"/><path d="M76 204 Q91 197 106 203" fill="none" stroke-width="6" stroke-linecap="round"/>',
    },
    "sadness": {
        "name": "슬픔",
        "outer": "#70A7BF",
        "inner": "#CCEAF0",
        "body": "M113 24 C97 35 71 46 56 69 C42 90 38 105 23 130 C5 158 3 190 17 216 C34 247 66 254 95 253 C130 252 159 239 175 211 C192 181 179 146 158 121 C143 103 122 88 116 62 C113 49 114 35 113 24 Z",
        "core": "M102 88 C91 104 73 119 56 141 C40 163 37 188 49 208 C62 228 91 234 114 225 C135 216 145 197 140 175 C134 149 115 128 106 108 C103 100 102 94 102 88 Z",
        "face": '<ellipse cx="70" cy="171" rx="6" ry="7"/><ellipse cx="113" cy="171" rx="6" ry="7"/><path d="M63 157 Q71 155 79 150 M105 150 Q113 155 120 157" fill="none" stroke-width="4" stroke-linecap="round"/><path d="M72 207 Q90 194 110 207" fill="none" stroke-width="5.5" stroke-linecap="round"/>',
    },
    "calm": {
        "name": "평온",
        "outer": "#88B9A9",
        "inner": "#D9ECCD",
        "body": "M93 31 C84 51 73 67 57 84 C31 110 10 136 3 169 C-4 201 14 231 44 245 C71 258 119 256 147 242 C176 228 190 199 183 169 C176 140 154 113 131 91 C110 72 101 54 93 31 Z",
        "core": "M93 91 C84 108 66 123 52 145 C38 166 37 190 50 210 C64 229 91 234 115 225 C138 216 148 193 141 172 C135 151 113 126 101 107 C98 101 95 96 93 91 Z",
        "face": '<path d="M59 170 Q70 180 80 170 M105 170 Q116 180 127 170" fill="none" stroke-width="5" stroke-linecap="round"/><path d="M72 202 Q92 213 113 202" fill="none" stroke-width="5.5" stroke-linecap="round"/>',
    },
}

for slug, flame in FLAMES.items():
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="206" height="273" viewBox="-10 -10 206 273" role="img" aria-label="{flame["name"]} 불꽃">
  <path d="{flame["body"]}" fill="{flame["outer"]}"/>
  <path d="{flame["core"]}" fill="{flame["inner"]}"/>
  <g fill="#29252A" stroke="#29252A">{flame["face"]}</g>
</svg>
'''
    target = ROOT / f"Explorations/{slug}-vector.svg"
    target.write_text(svg)
