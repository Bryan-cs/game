# -*- coding: utf-8 -*-
"""
Nightfall Survivors — generador procedural de spritesheets pixel-perfect.
Genera 8 personajes con 5 animaciones (idle 4, walk 6, attack 5, hit 2, death 5)
en frames de 64x64 alineados en grid, fondo transparente, listos para
AnimatedSprite2D de Godot 4. También genera un showcase etiquetado.
"""
import os
from PIL import Image, ImageDraw, ImageFont

PIX = 2          # cada pixel lógico son 2x2 px reales
LOG = 32         # lienzo lógico 32x32 -> frame 64x64
FRAME = LOG * PIX
ANIMS = [("IDLE", 4), ("WALK", 6), ("ATTACK", 5), ("HIT", 2), ("DEATH", 5)]
COLS = 6
SALIDA = os.path.join(os.path.dirname(__file__), "..", "art", "spritesheets")


def mezclar(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


class Lienzo:
    def __init__(self, img, ox, oy, flash=False, dissolve=0.0, seed=1):
        self.d = ImageDraw.Draw(img)
        self.ox, self.oy = ox, oy
        self.flash = flash
        self.dis = dissolve
        self.seed = seed

    def px(self, x, y, color, alpha=255):
        if x < 0 or y < 0 or x >= LOG or y >= LOG:
            return
        if self.dis > 0:
            h = ((x * 73856093) ^ (y * 19349663) ^ (self.seed * 83492791)) & 0xFFFF
            if (h % 1000) / 1000.0 < self.dis:
                return
        if self.flash:
            color = mezclar(color, (255, 70, 70), 0.65)
        rx = self.ox + x * PIX
        ry = self.oy + y * PIX
        self.d.rectangle([rx, ry, rx + PIX - 1, ry + PIX - 1], fill=color + (alpha,))

    def rect(self, x0, y0, x1, y1, color):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, color)


PERSONAJES = [
    {
        "id": "shadow_knight", "nombre": "Shadow Knight", "seed": 11,
        "armor": (52, 46, 70), "shade": (33, 29, 48), "accent": (168, 85, 247),
        "cabeza": "helmet", "ancho": 6, "arma": "sword",
    },
    {
        "id": "blood_mage", "nombre": "Blood Mage", "seed": 23,
        "armor": (96, 20, 34), "shade": (62, 12, 22), "accent": (239, 68, 68),
        "cabeza": "hood", "ancho": 5, "arma": "orbs",
    },
    {
        "id": "moon_huntress", "nombre": "Moon Huntress", "seed": 37,
        "armor": (72, 84, 116), "shade": (48, 56, 82), "accent": (203, 213, 225),
        "cabeza": "hair", "ancho": 4, "arma": "daggers",
    },
    {
        "id": "plague_alchemist", "nombre": "Plague Alchemist", "seed": 41,
        "armor": (64, 50, 32), "shade": (43, 33, 21), "accent": (74, 222, 128),
        "cabeza": "beak", "ancho": 5, "arma": "flask",
    },
    {
        "id": "infernal_berserker", "nombre": "Infernal Berserker", "seed": 53,
        "armor": (142, 62, 42), "shade": (100, 42, 28), "accent": (251, 113, 36),
        "cabeza": "rage", "ancho": 7, "arma": "axe",
    },
    {
        "id": "necromancer", "nombre": "Necromancer", "seed": 67,
        "armor": (58, 36, 84), "shade": (39, 23, 58), "accent": (192, 132, 252),
        "cabeza": "hood", "ancho": 5, "arma": "staff",
    },
    {
        "id": "arcane_engineer", "nombre": "Arcane Engineer", "seed": 79,
        "armor": (42, 62, 94), "shade": (27, 43, 66), "accent": (56, 189, 248),
        "cabeza": "goggles", "ancho": 5, "arma": "drone",
    },
    {
        "id": "void_priestess", "nombre": "Void Priestess", "seed": 97,
        "armor": (52, 42, 78), "shade": (32, 25, 50), "accent": (155, 110, 255),
        "cabeza": "veil", "ancho": 5, "arma": "void",
    },
]


def dibujar_cabeza(L, c, cx, ty):
    a, s, acc = c["armor"], c["shade"], c["accent"]
    modo = c["cabeza"]
    L.rect(cx - 3, ty, cx + 3, ty + 5, a)
    L.rect(cx - 3, ty + 4, cx + 3, ty + 5, s)
    if modo == "helmet":
        L.rect(cx - 3, ty - 1, cx + 3, ty, s)
        L.rect(cx - 3, ty + 2, cx + 3, ty + 2, (10, 8, 16))
        L.px(cx - 2, ty + 2, acc)
        L.px(cx + 2, ty + 2, acc)
        L.px(cx, ty - 2, acc)  # pluma/cresta
    elif modo == "hood":
        L.rect(cx - 4, ty - 1, cx + 4, ty + 1, s)
        L.px(cx, ty - 2, s)
        L.rect(cx - 2, ty + 2, cx + 2, ty + 4, (12, 8, 16))
        L.px(cx - 1, ty + 3, acc)
        L.px(cx + 1, ty + 3, acc)
    elif modo == "hair":
        L.rect(cx - 3, ty - 1, cx + 3, ty, acc)
        L.px(cx + 4, ty + 1, acc)
        L.px(cx - 1, ty + 3, (230, 240, 255))
        L.px(cx + 1, ty + 3, (230, 240, 255))
    elif modo == "beak":
        L.rect(cx - 3, ty - 1, cx + 3, ty, s)
        L.rect(cx + 3, ty + 2, cx + 6, ty + 3, (225, 220, 200))
        L.px(cx - 1, ty + 2, acc)
        L.px(cx + 1, ty + 2, acc)
    elif modo == "rage":
        L.px(cx - 2, ty + 2, (255, 40, 40))
        L.px(cx + 2, ty + 2, (255, 40, 40))
        L.px(cx - 4, ty, s)
        L.px(cx + 4, ty, s)  # cuernos
        L.px(cx - 5, ty - 1, s)
        L.px(cx + 5, ty - 1, s)
    elif modo == "goggles":
        L.rect(cx - 3, ty + 1, cx + 3, ty + 2, (20, 26, 34))
        L.px(cx - 2, ty + 1, acc)
        L.px(cx + 2, ty + 1, acc)
        L.px(cx, ty - 1, (180, 130, 60))  # remache cobre
    elif modo == "veil":
        L.rect(cx - 4, ty - 1, cx + 4, ty + 1, s)
        L.rect(cx - 2, ty + 2, cx + 2, ty + 4, (8, 6, 14))
        L.px(cx, ty + 3, acc)


def dibujar_arma(L, c, cx, hy, pose, fx):
    acc = c["accent"]
    arma = c["arma"]
    modo = pose.get("arm", "idle")
    trail = pose.get("trail", False)
    hx = cx + c["ancho"] + 1  # mano derecha

    if arma == "sword":
        if modo == "idle":
            for i in range(9):
                L.px(hx, hy - i, acc if i % 2 == 0 else mezclar(acc, (255, 255, 255), 0.3))
        elif modo == "up":
            for i in range(9):
                L.px(hx - 1, hy - 4 - i, acc)
        elif modo == "mid":
            for i in range(8):
                L.px(hx + i // 2, hy - 6 + i, acc)
            if trail:
                for i in range(6):
                    L.px(hx + 2 + i // 2, hy - 8 + i, mezclar(acc, (255, 255, 255), 0.5), 150)
        elif modo == "fwd":
            for i in range(9):
                L.px(hx + i, hy - 1, acc)
            if trail:
                for i in range(7):
                    L.px(hx + 1 + i, hy - 4, mezclar(acc, (255, 255, 255), 0.5), 150)
                    L.px(hx + i, hy - 7, acc, 90)
    elif arma == "axe":
        if modo in ("idle", "up"):
            base = hy - (4 if modo == "up" else 0)
            for i in range(8):
                L.px(hx, base - i, (120, 90, 60))
            L.rect(hx - 1, base - 10, hx + 2, base - 7, (160, 160, 170))
            L.px(hx + 2, base - 9, acc)
        else:
            alcance = 4 if modo == "mid" else 8
            for i in range(alcance):
                L.px(hx + i, hy - 2, (120, 90, 60))
            L.rect(hx + alcance - 1, hy - 4, hx + alcance + 2, hy, (160, 160, 170))
            if trail:
                for i in range(alcance + 2):
                    L.px(hx + i, hy - 6, acc, 130)
    elif arma == "daggers":
        izq = cx - c["ancho"] - 1
        if modo == "idle":
            for i in range(4):
                L.px(hx, hy - i, acc)
                L.px(izq, hy - i, acc)
        else:
            ext = {"up": 1, "mid": 3, "fwd": 5}.get(modo, 0)
            for i in range(4):
                L.px(hx + ext + i, hy - 1, acc)
                L.px(izq - max(0, ext - 2) - i, hy, acc)
            if trail:
                for i in range(5):
                    L.px(hx + ext + i, hy - 3, (230, 240, 255), 140)
    elif arma == "staff":
        for i in range(11):
            L.px(hx, hy + 2 - i, (90, 70, 50))
        orb_y = hy - 9
        L.rect(hx - 1, orb_y - 1, hx + 1, orb_y + 1, acc)
        if modo in ("mid", "fwd"):
            d = {"mid": 3, "fwd": 7}[modo]
            L.rect(hx + d, orb_y, hx + d + 1, orb_y + 1, acc)
            if trail:
                L.px(hx + d - 2, orb_y, mezclar(acc, (255, 255, 255), 0.4), 150)
    elif arma == "flask":
        if modo == "idle":
            L.rect(hx, hy - 2, hx + 1, hy, acc)
            L.px(hx, hy - 3, (180, 180, 180))
        else:
            d = {"up": 2, "mid": 5, "fwd": 9}.get(modo, 0)
            fy = hy - 4 - (2 if modo == "mid" else 0)
            L.rect(hx + d, fy, hx + d + 1, fy + 2, acc)
            if trail:
                for i in range(4):
                    L.px(hx + d + (i % 3) - 1, fy - 2 - i // 2, acc, 120)
    elif arma == "orbs":
        offs = [(-7, -10), (7, -12), (-6, -14), (6, -9)]
        o1 = offs[fx % 4]
        o2 = offs[(fx + 2) % 4]
        if modo in ("mid", "fwd"):
            d = {"mid": 4, "fwd": 9}[modo]
            L.rect(cx + d, hy - 8, cx + d + 1, hy - 7, acc)
            L.rect(cx + d - 3, hy - 11, cx + d - 2, hy - 10, acc)
            if trail:
                L.px(cx + d - 2, hy - 8, (255, 160, 160), 140)
        else:
            L.rect(cx + o1[0], hy + o1[1], cx + o1[0] + 1, hy + o1[1] + 1, acc)
            L.rect(cx + o2[0], hy + o2[1], cx + o2[0] + 1, hy + o2[1] + 1, acc)
    elif arma == "drone":
        dy = hy - 14 + (fx % 2)
        dx = cx - 9
        L.rect(dx, dy, dx + 2, dy + 1, (120, 130, 150))
        L.px(dx + 1, dy - 1, acc)
        if modo in ("mid", "fwd"):
            alcance = {"mid": 5, "fwd": 10}[modo]
            for i in range(alcance):
                if i % 2 == fx % 2:
                    L.px(dx + 3 + i, dy + 1, acc, 200)
    elif arma == "void":
        oy = hy - 12 - (fx % 2)
        if modo in ("mid", "fwd"):
            r = {"mid": 2, "fwd": 4}[modo]
            for ang in range(8):
                px_ = cx + int(r * [1, 0.7, 0, -0.7, -1, -0.7, 0, 0.7][ang])
                py_ = oy + int(r * [0, 0.7, 1, 0.7, 0, -0.7, -1, -0.7][ang])
                L.px(px_, py_, acc, 200)
            L.px(cx, oy, (5, 3, 10))
        else:
            L.rect(cx - 1, oy, cx + 1, oy + 1, (8, 5, 14))
            L.px(cx - 2, oy, acc, 160)
            L.px(cx + 2, oy + 1, acc, 160)


def dibujar_extras(L, c, cx, fx):
    acc = c["accent"]
    s = c["seed"]
    if c["arma"] in ("staff",):  # almas flotantes
        for k in range(3):
            x = cx - 10 + ((s * (k + 3) + fx * 2) % 20)
            y = 8 + ((s * (k + 7) + fx * 3) % 10)
            L.px(x, y, mezclar(acc, (255, 255, 255), 0.4), 140)
    if c["id"] == "infernal_berserker":  # brasas
        for k in range(3):
            x = cx - 8 + ((s * (k + 2) + fx * 3) % 16)
            y = 12 + ((s * (k + 5) + fx * 2) % 12)
            L.px(x, y, acc, 150)
    if c["id"] == "plague_alchemist":  # humo tóxico
        for k in range(2):
            x = cx + 4 + ((s + k * 5 + fx * 2) % 6)
            y = 10 + ((s + k * 9 + fx) % 6)
            L.px(x, y, acc, 110)
    if c["id"] == "void_priestess":  # tela flotante
        for k in range(3):
            x = cx - 6 - k
            y = 22 + ((fx + k) % 3) - 1
            L.px(x, y, c["shade"], 200)


def dibujar_personaje(img, ox, oy, c, pose, fx):
    L = Lienzo(img, ox, oy, pose.get("flash", False), pose.get("dissolve", 0.0), c["seed"])
    bob = pose.get("bob", 0) + pose.get("fall", 0)
    cx = 16
    W = c["ancho"]
    base = 29 + bob
    a, s = c["armor"], c["shade"]

    # piernas
    fase = pose.get("legs", -1)
    li = ld = 0
    if fase >= 0:
        ciclo = [0, 2, 1, 0, 0, 0]
        li = ciclo[fase % 6]
        ld = ciclo[(fase + 3) % 6]
    for i in range(5):
        if i < 5 - li:
            L.px(cx - 2, base - i, s)
            L.px(cx - 3, base - i, s)
        if i < 5 - ld:
            L.px(cx + 2, base - i, s)
            L.px(cx + 3, base - i, s)

    # torso
    ty = base - 13 + (1 if fase in (1, 4) else 0)
    L.rect(cx - W, ty, cx + W, ty + 8, a)
    L.rect(cx - W, ty + 6, cx + W, ty + 8, s)
    L.px(cx, ty + 2, c["accent"])  # emblema pecho

    # brazos
    modo = pose.get("arm", "idle")
    if modo == "idle":
        L.rect(cx - W - 1, ty + 1, cx - W - 1, ty + 6, s)
        L.rect(cx + W + 1, ty + 1, cx + W + 1, ty + 6, s)
    elif modo == "up":
        L.rect(cx - W - 1, ty + 1, cx - W - 1, ty + 6, s)
        L.rect(cx + W + 1, ty - 3, cx + W + 1, ty + 2, s)
    else:
        L.rect(cx - W - 1, ty + 1, cx - W - 1, ty + 6, s)
        L.rect(cx + W + 1, ty + 2, cx + W + 2, ty + 3, s)

    # cabeza
    dibujar_cabeza(L, c, cx, ty - 7)

    # arma y extras
    dibujar_arma(L, c, cx, ty + 5, pose, fx)
    dibujar_extras(L, c, cx, fx)

    # partículas de muerte ascendiendo
    dis = pose.get("dissolve", 0.0)
    if dis > 0:
        Lp = Lienzo(img, ox, oy, False, 0.0, c["seed"])
        n = int(3 + dis * 7)
        for k in range(n):
            x = 8 + ((c["seed"] * (k + 1) * 7) % 16)
            y = int(26 - dis * 18) - ((c["seed"] * (k + 3)) % 8)
            Lp.px(x, y, c["accent"], int(220 - dis * 150))


def poses_de(anim, frames):
    poses = []
    for f in range(frames):
        p = {}
        if anim == "IDLE":
            p["bob"] = [0, 1, 1, 0][f % 4]
        elif anim == "WALK":
            p["legs"] = f
            p["bob"] = 1 if f % 3 == 1 else 0
        elif anim == "ATTACK":
            p["arm"] = ["up", "up", "mid", "fwd", "idle"][f]
            p["trail"] = f in (2, 3)
        elif anim == "HIT":
            p["flash"] = True
            p["bob"] = [0, 1][f]
        elif anim == "DEATH":
            p["dissolve"] = f / 4.5
            p["fall"] = f
        poses.append(p)
    return poses


def hoja_personaje(c):
    filas = len(ANIMS)
    img = Image.new("RGBA", (COLS * FRAME, filas * FRAME), (0, 0, 0, 0))
    for fila, (anim, n) in enumerate(ANIMS):
        for f, pose in enumerate(poses_de(anim, n)):
            dibujar_personaje(img, f * FRAME, fila * FRAME, c, pose, f)
    return img


def fuente(tam):
    for ruta in ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/arial.ttf"]:
        if os.path.exists(ruta):
            return ImageFont.truetype(ruta, tam)
    return ImageFont.load_default()


def showcase(hojas):
    margen = 24
    etiqueta_w = 76
    bloque_w = etiqueta_w + COLS * FRAME + margen
    bloque_h = 30 + len(ANIMS) * FRAME + margen
    cols_b = 2
    filas_b = 4
    W = margen + cols_b * bloque_w
    H = 70 + filas_b * bloque_h
    img = Image.new("RGBA", (W, H), (18, 14, 28, 255))
    d = ImageDraw.Draw(img)
    f_titulo = fuente(30)
    f_nombre = fuente(17)
    f_label = fuente(11)
    d.text((margen, 18), "NIGHTFALL SURVIVORS — CHARACTER ROSTER", font=f_titulo, fill=(196, 160, 255))
    for i, (c, hoja) in enumerate(hojas):
        bx = margen + (i % cols_b) * bloque_w
        by = 70 + (i // cols_b) * bloque_h
        d.rectangle([bx - 6, by - 4, bx + etiqueta_w + COLS * FRAME + 4, by + 24 + len(ANIMS) * FRAME + 4],
                    outline=(70, 50, 110), width=1)
        d.text((bx, by), c["nombre"], font=f_nombre, fill=c["accent"])
        for fila, (anim, n) in enumerate(ANIMS):
            d.text((bx, by + 28 + fila * FRAME + FRAME // 2 - 7), anim, font=f_label, fill=(150, 140, 180))
        img.alpha_composite(hoja, (bx + etiqueta_w, by + 28))
    return img


def main():
    os.makedirs(SALIDA, exist_ok=True)
    hojas = []
    for c in PERSONAJES:
        hoja = hoja_personaje(c)
        ruta = os.path.join(SALIDA, c["id"] + ".png")
        hoja.save(ruta)
        hojas.append((c, hoja))
        print("ok", ruta)
    sc = showcase(hojas)
    sc.save(os.path.join(SALIDA, "roster_showcase.png"))
    print("ok showcase")


if __name__ == "__main__":
    main()
