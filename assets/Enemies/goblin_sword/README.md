# Goblin con espada — paquete de sprites

- Hoja principal: `goblin-sword-spritesheet.png`
- Formato: PNG RGBA con transparencia
- Cuadrícula: 6 columnas × 4 filas
- Celda: 256 × 256 px
- Filas: abajo, arriba, izquierda, derecha
- Animación: 6 fotogramas por dirección, bucle a 10 FPS
- Punto de origen recomendado: `(128, 220)`

La carpeta `frames/` contiene los 24 fotogramas individuales. El archivo
`goblin-sword.animations.json` describe la cuadrícula y las animaciones para
facilitar la importación en Godot, Unity, GameMaker u otro motor 2D.

Para pixel art, usa filtrado `Nearest/Point`, desactiva mipmaps y evita que el
motor comprima la textura con pérdida.
