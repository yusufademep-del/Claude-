/* Börsenlehre – 3D-Szene im Hero: schwebende Münzen, wachsendes Balkendiagramm, Pfeil nach oben */
(function () {
  var canvas = document.getElementById("hero3d");
  if (!canvas || typeof THREE === "undefined") return;
  var hero = canvas.parentElement;
  var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  var renderer;
  try {
    renderer = new THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: true });
  } catch (e) { canvas.remove(); return; }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.outputEncoding = THREE.sRGBEncoding;

  var scene = new THREE.Scene();
  var camera = new THREE.PerspectiveCamera(40, 1, 0.1, 100);
  camera.position.set(0, 0, 14);

  // Licht
  scene.add(new THREE.AmbientLight(0xbfd0ff, 0.55));
  var key = new THREE.DirectionalLight(0xffffff, 1.1);
  key.position.set(4, 6, 8); scene.add(key);
  var warm = new THREE.PointLight(0xffd60a, 1.4, 30);
  warm.position.set(-5, 2, 6); scene.add(warm);
  var rim = new THREE.PointLight(0x5b8cff, 1.0, 30);
  rim.position.set(6, -3, 4); scene.add(rim);

  // Materialien
  var gold = new THREE.MeshStandardMaterial({ color: 0xffc928, metalness: 0.85, roughness: 0.28, emissive: 0x3a2a00, emissiveIntensity: 0.25 });
  var goldEdge = new THREE.MeshStandardMaterial({ color: 0xe0a800, metalness: 0.9, roughness: 0.35 });
  var green = new THREE.MeshStandardMaterial({ color: 0x22c55e, metalness: 0.25, roughness: 0.35, emissive: 0x06381a, emissiveIntensity: 0.4 });
  var greenTop = new THREE.MeshStandardMaterial({ color: 0x4ade80, metalness: 0.2, roughness: 0.3 });
  var yellow = new THREE.MeshStandardMaterial({ color: 0xffd60a, metalness: 0.4, roughness: 0.3, emissive: 0x4a3c00, emissiveIntensity: 0.35 });

  // Münzen
  var coinGeo = new THREE.CylinderGeometry(0.62, 0.62, 0.14, 48);
  var rimGeo = new THREE.TorusGeometry(0.62, 0.05, 12, 48);
  var coins = [];
  function makeCoin(x, y, z, s) {
    var g = new THREE.Group();
    var body = new THREE.Mesh(coinGeo, [goldEdge, gold, gold]);
    body.rotation.x = Math.PI / 2;
    g.add(body);
    var r1 = new THREE.Mesh(rimGeo, goldEdge); r1.position.z = 0.07; g.add(r1);
    var r2 = new THREE.Mesh(rimGeo, goldEdge); r2.position.z = -0.07; g.add(r2);
    g.position.set(x, y, z);
    g.scale.setScalar(s);
    g.userData = { baseY: y, phase: Math.random() * Math.PI * 2, spin: 0.4 + Math.random() * 0.6, bob: 0.15 + Math.random() * 0.2 };
    g.rotation.set(Math.random() * 0.6, Math.random() * Math.PI, Math.random() * 0.4);
    scene.add(g); coins.push(g);
  }

  // Balkendiagramm (wächst beim Laden)
  var chart = new THREE.Group();
  var heights = [0.9, 1.4, 1.2, 2.0, 2.7, 3.6];
  var bars = [];
  heights.forEach(function (h, i) {
    var geo = new THREE.BoxGeometry(0.55, 1, 0.55);
    geo.translate(0, 0.5, 0); // wächst vom Boden aus
    var m = new THREE.Mesh(geo, [green, green, greenTop, green, green, green]);
    m.position.x = i * 0.75;
    m.userData.h = h;
    m.scale.y = reduce ? h : 0.001;
    chart.add(m); bars.push(m);
  });
  // Pfeil nach oben über dem Diagramm
  var arrow = new THREE.Group();
  var shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 1.3, 16), yellow);
  shaft.position.y = 0.65; arrow.add(shaft);
  var head = new THREE.Mesh(new THREE.ConeGeometry(0.32, 0.6, 24), yellow);
  head.position.y = 1.55; arrow.add(head);
  arrow.rotation.z = -0.55;
  arrow.position.set(4.3, 3.9, 0.3);
  chart.add(arrow);
  chart.rotation.set(0.18, -0.55, 0);
  scene.add(chart);

  var layoutWide = null;
  function layout(w, h) {
    var wide = w > 860;
    if (wide === layoutWide) return;
    layoutWide = wide;
    coins.forEach(function (c) { scene.remove(c); }); coins.length = 0;
    if (wide) {
      chart.position.set(-0.9, -4.6, -1.5); chart.scale.setScalar(1.15);
      makeCoin(0.6, 5.6, -6, 0.6); makeCoin(3.0, 4.6, -3, 0.75);
      makeCoin(7.6, 3.4, -2, 1.1); makeCoin(8.2, -1.4, -1, 0.95);
      makeCoin(5.6, -4.6, 0.5, 0.75);
    } else {
      chart.position.set(-2.1, -7.4, -3.5); chart.scale.setScalar(0.85);
      makeCoin(-3.2, 6.2, -3, 0.75); makeCoin(3.3, 5.0, -2, 0.85); makeCoin(3.6, -1.5, -2, 0.7);
      makeCoin(-3.6, -3.4, -3, 0.65); makeCoin(2.2, -6.6, -1, 0.7);
    }
  }

  function resize() {
    var w = hero.clientWidth, h = hero.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    layout(w, h);
    if (reduce) render(0);
  }

  // Maus-Parallaxe
  var mx = 0, my = 0, cx = 0, cy = 0;
  hero.addEventListener("pointermove", function (e) {
    var r = hero.getBoundingClientRect();
    mx = ((e.clientX - r.left) / r.width - 0.5) * 2;
    my = ((e.clientY - r.top) / r.height - 0.5) * 2;
  });
  hero.addEventListener("pointerleave", function () { mx = 0; my = 0; });

  function easeOutBack(t) { var c1 = 1.4, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); }

  var start = performance.now();
  function render(now) {
    var t = (now - start) / 1000;
    cx += (mx - cx) * 0.05; cy += (my - cy) * 0.05;
    camera.position.x = cx * 0.9;
    camera.position.y = -cy * 0.6;
    camera.lookAt(0, 0, 0);

    coins.forEach(function (c) {
      var u = c.userData;
      c.position.y = u.baseY + Math.sin(t * 1.1 + u.phase) * u.bob;
      c.rotation.y += 0.012 * u.spin;
    });
    bars.forEach(function (b, i) {
      var p = Math.min(Math.max((t - 0.25 - i * 0.12) / 0.9, 0), 1);
      var grow = reduce ? 1 : easeOutBack(p);
      b.scale.y = Math.max(0.001, b.userData.h * grow * (1 + 0.03 * Math.sin(t * 1.6 + i)));
    });
    arrow.position.y = 3.9 + Math.sin(t * 1.4) * 0.15;
    chart.rotation.y = -0.55 + Math.sin(t * 0.35) * 0.12;
    renderer.render(scene, camera);
  }

  var running = !reduce, raf = 0, visible = true;
  function loop(now) { render(now); if (running && visible) raf = requestAnimationFrame(loop); }
  if ("IntersectionObserver" in window) {
    new IntersectionObserver(function (es) {
      visible = es[0].isIntersecting;
      if (visible && running) { cancelAnimationFrame(raf); raf = requestAnimationFrame(loop); }
    }).observe(hero);
  }
  if ("ResizeObserver" in window) new ResizeObserver(resize).observe(hero); else window.addEventListener("resize", resize);
  resize();
  if (running) raf = requestAnimationFrame(loop); else render(performance.now());
})();

/* 3D-Kippeffekt für Karten */
(function () {
  if (window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
  if (window.matchMedia && !window.matchMedia("(hover: hover)").matches) return;
  document.querySelectorAll("[data-tilt]").forEach(function (el) {
    el.addEventListener("pointermove", function (e) {
      var r = el.getBoundingClientRect();
      var x = (e.clientX - r.left) / r.width - 0.5;
      var y = (e.clientY - r.top) / r.height - 0.5;
      el.style.transform = "perspective(900px) rotateX(" + (-y * 8).toFixed(2) + "deg) rotateY(" + (x * 10).toFixed(2) + "deg) translateY(-4px)";
      el.style.setProperty("--gx", ((x + 0.5) * 100).toFixed(1) + "%");
      el.style.setProperty("--gy", ((y + 0.5) * 100).toFixed(1) + "%");
    });
    el.addEventListener("pointerleave", function () { el.style.transform = ""; });
  });
})();
