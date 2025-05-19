--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5 (Debian 17.5-1.pgdg120+1)
-- Dumped by pg_dump version 17.5 (Debian 17.5-1.pgdg120+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: fn_actualizar_stock_ingredientes(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_actualizar_stock_ingredientes() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Para cada detalle de pedido, restar cantidad del stock del ingrediente correspondiente
  UPDATE Ingredientes i
  SET stock = stock - dp.cantidad
  FROM DetallesPedido dp
  WHERE dp.plato_id = NEW.plato_id AND i.id = (
    SELECT ingrediente_id FROM Recetas WHERE plato_id = dp.plato_id LIMIT 1
  )
  AND dp.pedido_id = NEW.pedido_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_actualizar_stock_ingredientes() OWNER TO postgres;

--
-- Name: fn_calcular_costo_plato(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_calcular_costo_plato(plato_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    costo_total NUMERIC := 0;
BEGIN
    SELECT SUM(i.costo_unitario * r.cantidad) INTO costo_total
    FROM Recetas r
    JOIN Ingredientes i ON r.ingrediente_id = i.id
    WHERE r.plato_id = plato_id;

    RETURN costo_total;
END;
$$;


ALTER FUNCTION public.fn_calcular_costo_plato(plato_id integer) OWNER TO postgres;

--
-- Name: fn_cambiar_estado_mesa(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_cambiar_estado_mesa() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE Mesas SET estado = 'ocupada' WHERE id = NEW.mesa_id;
  ELSIF TG_OP = 'UPDATE' AND NEW.estado = 'cerrado' THEN
    UPDATE Mesas SET estado = 'libre' WHERE id = NEW.mesa_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_cambiar_estado_mesa() OWNER TO postgres;

--
-- Name: fn_registrar_factura(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_registrar_factura() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.estado = 'cerrado' THEN
    INSERT INTO Facturas (pedido_id, total, fecha)
    VALUES (NEW.id,
      (SELECT SUM(pl.precio * dp.cantidad)
       FROM DetallesPedido dp
       JOIN Platos pl ON dp.plato_id = pl.id
       WHERE dp.pedido_id = NEW.id),
      NOW());
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_registrar_factura() OWNER TO postgres;

--
-- Name: fn_total_factura(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_total_factura(pedido_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    total NUMERIC;
BEGIN
    SELECT SUM(pl.precio * dp.cantidad) INTO total
    FROM DetallesPedido dp
    JOIN Platos pl ON dp.plato_id = pl.id
    WHERE dp.pedido_id = pedido_id;

    RETURN COALESCE(total, 0);
END;
$$;


ALTER FUNCTION public.fn_total_factura(pedido_id integer) OWNER TO postgres;

--
-- Name: fn_total_facturas_por_mesa(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_total_facturas_por_mesa(mesa_id integer) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
    total NUMERIC;
BEGIN
    SELECT SUM(f.total) INTO total
    FROM Facturas f
    JOIN Pedidos p ON f.pedido_id = p.id
    WHERE p.mesa_id = mesa_id;

    RETURN COALESCE(total, 0);
END;
$$;


ALTER FUNCTION public.fn_total_facturas_por_mesa(mesa_id integer) OWNER TO postgres;

--
-- Name: fn_total_platos_pedido(integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.fn_total_platos_pedido(pedido_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    cantidad_total INT;
BEGIN
    SELECT SUM(cantidad) INTO cantidad_total
    FROM DetallesPedido
    WHERE pedido_id = pedido_id;

    RETURN COALESCE(cantidad_total, 0);
END;
$$;


ALTER FUNCTION public.fn_total_platos_pedido(pedido_id integer) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: asignacionesmesa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.asignacionesmesa (
    id integer NOT NULL,
    mesa_id integer NOT NULL,
    empleado_id integer NOT NULL
);


ALTER TABLE public.asignacionesmesa OWNER TO postgres;

--
-- Name: asignacionesmesa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.asignacionesmesa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.asignacionesmesa_id_seq OWNER TO postgres;

--
-- Name: asignacionesmesa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.asignacionesmesa_id_seq OWNED BY public.asignacionesmesa.id;


--
-- Name: categoriasplato; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categoriasplato (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL
);


ALTER TABLE public.categoriasplato OWNER TO postgres;

--
-- Name: categoriasplato_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categoriasplato_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categoriasplato_id_seq OWNER TO postgres;

--
-- Name: categoriasplato_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categoriasplato_id_seq OWNED BY public.categoriasplato.id;


--
-- Name: detallespedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.detallespedido (
    id integer NOT NULL,
    pedido_id integer NOT NULL,
    plato_id integer NOT NULL,
    cantidad integer NOT NULL
);


ALTER TABLE public.detallespedido OWNER TO postgres;

--
-- Name: detallespedido_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.detallespedido_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.detallespedido_id_seq OWNER TO postgres;

--
-- Name: detallespedido_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.detallespedido_id_seq OWNED BY public.detallespedido.id;


--
-- Name: empleados; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.empleados (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    rol_id integer NOT NULL
);


ALTER TABLE public.empleados OWNER TO postgres;

--
-- Name: empleados_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.empleados_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.empleados_id_seq OWNER TO postgres;

--
-- Name: empleados_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.empleados_id_seq OWNED BY public.empleados.id;


--
-- Name: estadosmesa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estadosmesa (
    id integer NOT NULL,
    descripcion character varying(50) NOT NULL
);


ALTER TABLE public.estadosmesa OWNER TO postgres;

--
-- Name: estadosmesa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estadosmesa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.estadosmesa_id_seq OWNER TO postgres;

--
-- Name: estadosmesa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estadosmesa_id_seq OWNED BY public.estadosmesa.id;


--
-- Name: estadospedido; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.estadospedido (
    id integer NOT NULL,
    descripcion character varying(50) NOT NULL
);


ALTER TABLE public.estadospedido OWNER TO postgres;

--
-- Name: estadospedido_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.estadospedido_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.estadospedido_id_seq OWNER TO postgres;

--
-- Name: estadospedido_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.estadospedido_id_seq OWNED BY public.estadospedido.id;


--
-- Name: facturas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.facturas (
    id integer NOT NULL,
    pedido_id integer NOT NULL,
    total numeric(10,2) NOT NULL,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.facturas OWNER TO postgres;

--
-- Name: facturas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.facturas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.facturas_id_seq OWNER TO postgres;

--
-- Name: facturas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.facturas_id_seq OWNED BY public.facturas.id;


--
-- Name: ingredientes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ingredientes (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    stock numeric(10,2) DEFAULT 0 NOT NULL,
    unidad_medida character varying(50)
);


ALTER TABLE public.ingredientes OWNER TO postgres;

--
-- Name: ingredientes_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ingredientes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ingredientes_id_seq OWNER TO postgres;

--
-- Name: ingredientes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ingredientes_id_seq OWNED BY public.ingredientes.id;


--
-- Name: inventario; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventario (
    id integer NOT NULL,
    ingrediente_id integer NOT NULL,
    cantidad numeric(10,2) NOT NULL
);


ALTER TABLE public.inventario OWNER TO postgres;

--
-- Name: inventario_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventario_id_seq OWNER TO postgres;

--
-- Name: inventario_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventario_id_seq OWNED BY public.inventario.id;


--
-- Name: mesas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mesas (
    id integer NOT NULL,
    numero integer NOT NULL,
    estado character varying(20) NOT NULL
);


ALTER TABLE public.mesas OWNER TO postgres;

--
-- Name: mesas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mesas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.mesas_id_seq OWNER TO postgres;

--
-- Name: mesas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mesas_id_seq OWNED BY public.mesas.id;


--
-- Name: pedidos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pedidos (
    id integer NOT NULL,
    mesa_id integer NOT NULL,
    empleado_id integer NOT NULL,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    estado character varying(50) DEFAULT 'pendiente'::character varying
);


ALTER TABLE public.pedidos OWNER TO postgres;

--
-- Name: pedidos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.pedidos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pedidos_id_seq OWNER TO postgres;

--
-- Name: pedidos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.pedidos_id_seq OWNED BY public.pedidos.id;


--
-- Name: platos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.platos (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    precio numeric(10,2) NOT NULL,
    categoria_id integer NOT NULL
);


ALTER TABLE public.platos OWNER TO postgres;

--
-- Name: platos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.platos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.platos_id_seq OWNER TO postgres;

--
-- Name: platos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.platos_id_seq OWNED BY public.platos.id;


--
-- Name: proveedores; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.proveedores (
    id integer NOT NULL,
    nombre character varying(150) NOT NULL,
    contacto character varying(100)
);


ALTER TABLE public.proveedores OWNER TO postgres;

--
-- Name: proveedores_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.proveedores_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proveedores_id_seq OWNER TO postgres;

--
-- Name: proveedores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.proveedores_id_seq OWNED BY public.proveedores.id;


--
-- Name: recetas; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.recetas (
    id integer NOT NULL,
    plato_id integer NOT NULL,
    ingrediente_id integer NOT NULL,
    cantidad numeric(10,2) NOT NULL
);


ALTER TABLE public.recetas OWNER TO postgres;

--
-- Name: recetas_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.recetas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.recetas_id_seq OWNER TO postgres;

--
-- Name: recetas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.recetas_id_seq OWNED BY public.recetas.id;


--
-- Name: reservasmesa; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reservasmesa (
    id integer NOT NULL,
    mesa_id integer NOT NULL,
    nombre_cliente character varying(100) NOT NULL,
    fecha timestamp without time zone NOT NULL
);


ALTER TABLE public.reservasmesa OWNER TO postgres;

--
-- Name: reservasmesa_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reservasmesa_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reservasmesa_id_seq OWNER TO postgres;

--
-- Name: reservasmesa_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reservasmesa_id_seq OWNED BY public.reservasmesa.id;


--
-- Name: rolesempleado; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rolesempleado (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL
);


ALTER TABLE public.rolesempleado OWNER TO postgres;

--
-- Name: rolesempleado_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rolesempleado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rolesempleado_id_seq OWNER TO postgres;

--
-- Name: rolesempleado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rolesempleado_id_seq OWNED BY public.rolesempleado.id;


--
-- Name: vista_ingredientes_bajo_stock; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_ingredientes_bajo_stock AS
 SELECT id,
    nombre,
    stock,
    unidad_medida
   FROM public.ingredientes
  WHERE (stock < (10)::numeric);


ALTER VIEW public.vista_ingredientes_bajo_stock OWNER TO postgres;

--
-- Name: vista_mesas_libres; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_mesas_libres AS
 SELECT id,
    numero,
    estado
   FROM public.mesas
  WHERE ((estado)::text = 'libre'::text);


ALTER VIEW public.vista_mesas_libres OWNER TO postgres;

--
-- Name: vista_pedidos_por_mesa; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_pedidos_por_mesa AS
 SELECT p.id AS pedido_id,
    p.mesa_id,
    e.nombre AS camarero,
    pl.nombre AS plato,
    dp.cantidad
   FROM (((public.pedidos p
     JOIN public.empleados e ON ((p.empleado_id = e.id)))
     JOIN public.detallespedido dp ON ((p.id = dp.pedido_id)))
     JOIN public.platos pl ON ((dp.plato_id = pl.id)))
  ORDER BY p.mesa_id, p.id;


ALTER VIEW public.vista_pedidos_por_mesa OWNER TO postgres;

--
-- Name: vista_platos_mas_pedidos; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vista_platos_mas_pedidos AS
 SELECT pl.id,
    pl.nombre,
    sum(dp.cantidad) AS total_pedidos
   FROM (public.platos pl
     JOIN public.detallespedido dp ON ((pl.id = dp.plato_id)))
  GROUP BY pl.id, pl.nombre
  ORDER BY (sum(dp.cantidad)) DESC;


ALTER VIEW public.vista_platos_mas_pedidos OWNER TO postgres;

--
-- Name: asignacionesmesa id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignacionesmesa ALTER COLUMN id SET DEFAULT nextval('public.asignacionesmesa_id_seq'::regclass);


--
-- Name: categoriasplato id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoriasplato ALTER COLUMN id SET DEFAULT nextval('public.categoriasplato_id_seq'::regclass);


--
-- Name: detallespedido id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallespedido ALTER COLUMN id SET DEFAULT nextval('public.detallespedido_id_seq'::regclass);


--
-- Name: empleados id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados ALTER COLUMN id SET DEFAULT nextval('public.empleados_id_seq'::regclass);


--
-- Name: estadosmesa id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadosmesa ALTER COLUMN id SET DEFAULT nextval('public.estadosmesa_id_seq'::regclass);


--
-- Name: estadospedido id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadospedido ALTER COLUMN id SET DEFAULT nextval('public.estadospedido_id_seq'::regclass);


--
-- Name: facturas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas ALTER COLUMN id SET DEFAULT nextval('public.facturas_id_seq'::regclass);


--
-- Name: ingredientes id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingredientes ALTER COLUMN id SET DEFAULT nextval('public.ingredientes_id_seq'::regclass);


--
-- Name: inventario id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario ALTER COLUMN id SET DEFAULT nextval('public.inventario_id_seq'::regclass);


--
-- Name: mesas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesas ALTER COLUMN id SET DEFAULT nextval('public.mesas_id_seq'::regclass);


--
-- Name: pedidos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos ALTER COLUMN id SET DEFAULT nextval('public.pedidos_id_seq'::regclass);


--
-- Name: platos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.platos ALTER COLUMN id SET DEFAULT nextval('public.platos_id_seq'::regclass);


--
-- Name: proveedores id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores ALTER COLUMN id SET DEFAULT nextval('public.proveedores_id_seq'::regclass);


--
-- Name: recetas id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recetas ALTER COLUMN id SET DEFAULT nextval('public.recetas_id_seq'::regclass);


--
-- Name: reservasmesa id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservasmesa ALTER COLUMN id SET DEFAULT nextval('public.reservasmesa_id_seq'::regclass);


--
-- Name: rolesempleado id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolesempleado ALTER COLUMN id SET DEFAULT nextval('public.rolesempleado_id_seq'::regclass);


--
-- Data for Name: asignacionesmesa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.asignacionesmesa (id, mesa_id, empleado_id) FROM stdin;
1	1	1
2	2	2
3	3	3
4	4	4
5	5	5
\.


--
-- Data for Name: categoriasplato; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categoriasplato (id, nombre) FROM stdin;
1	Entradas
2	Platos Fuertes
3	Postres
4	Bebidas
5	Especiales
\.


--
-- Data for Name: detallespedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.detallespedido (id, pedido_id, plato_id, cantidad) FROM stdin;
1	1	1	2
2	2	2	1
3	3	3	3
4	4	4	1
5	5	5	2
\.


--
-- Data for Name: empleados; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.empleados (id, nombre, rol_id) FROM stdin;
2	Maria Lopez	2
3	Carlos Ruiz	3
4	Ana Torres	4
5	Luis Gomez	5
6	Carlos	1
1	Carlos Pérez	1
\.


--
-- Data for Name: estadosmesa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.estadosmesa (id, descripcion) FROM stdin;
1	libre
2	ocupada
3	reservada
4	limpiando
5	fuera de servicio
\.


--
-- Data for Name: estadospedido; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.estadospedido (id, descripcion) FROM stdin;
1	pendiente
2	en preparación
3	entregado
4	cancelado
5	facturado
\.


--
-- Data for Name: facturas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.facturas (id, pedido_id, total, fecha) FROM stdin;
1	3	54000.00	2025-05-15 19:06:22.188818
2	1	50000.00	2025-05-15 19:06:22.188818
3	2	45000.00	2025-05-15 19:06:22.188818
4	5	16000.00	2025-05-15 19:06:22.188818
5	4	12000.00	2025-05-15 19:06:22.188818
\.


--
-- Data for Name: ingredientes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ingredientes (id, nombre, stock, unidad_medida) FROM stdin;
1	Tomate	100.00	kg
2	Carne	50.00	kg
3	Leche	30.00	litros
4	Azúcar	20.00	kg
5	Café	15.00	kg
\.


--
-- Data for Name: inventario; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventario (id, ingrediente_id, cantidad) FROM stdin;
1	1	100.00
2	2	50.00
3	3	30.00
4	4	20.00
5	5	15.00
\.


--
-- Data for Name: mesas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.mesas (id, numero, estado) FROM stdin;
1	1	libre
2	2	ocupada
3	3	reservada
4	4	libre
5	5	ocupada
\.


--
-- Data for Name: pedidos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pedidos (id, mesa_id, empleado_id, fecha, estado) FROM stdin;
2	3	2	2025-05-15 19:06:22.179097	en preparación
3	1	3	2025-05-15 19:06:22.179097	entregado
4	4	4	2025-05-15 19:06:22.179097	cancelado
5	5	5	2025-05-15 19:06:22.179097	pendiente
1	2	1	2025-05-15 19:06:22.179097	entregado
\.


--
-- Data for Name: platos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.platos (id, nombre, precio, categoria_id) FROM stdin;
2	Bistec a la Plancha	45000.00	2
3	Flan	18000.00	3
4	Jugo de Naranja	12000.00	4
5	Café Americano	8000.00	4
6	Hamburguesa	15000.00	1
1	Ensalada César	17000.00	1
\.


--
-- Data for Name: proveedores; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.proveedores (id, nombre, contacto) FROM stdin;
1	Proveedor A	proveedorA@email.com
2	Proveedor B	proveedorB@email.com
3	Proveedor C	proveedorC@email.com
4	Proveedor D	proveedorD@email.com
5	Proveedor E	proveedorE@email.com
\.


--
-- Data for Name: recetas; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.recetas (id, plato_id, ingrediente_id, cantidad) FROM stdin;
1	1	1	0.20
2	2	2	0.30
3	3	3	0.20
4	3	4	0.05
5	5	5	0.10
\.


--
-- Data for Name: reservasmesa; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reservasmesa (id, mesa_id, nombre_cliente, fecha) FROM stdin;
1	3	Cliente A	2025-05-16 19:06:22.174954
2	4	Cliente B	2025-05-17 19:06:22.174954
3	5	Cliente C	2025-05-18 19:06:22.174954
4	1	Cliente D	2025-05-19 19:06:22.174954
5	2	Cliente E	2025-05-20 19:06:22.174954
\.


--
-- Data for Name: rolesempleado; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rolesempleado (id, nombre) FROM stdin;
1	Camarero
2	Cocinero
3	Cajero
4	Gerente
5	Administrador
\.


--
-- Name: asignacionesmesa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.asignacionesmesa_id_seq', 5, true);


--
-- Name: categoriasplato_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categoriasplato_id_seq', 5, true);


--
-- Name: detallespedido_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.detallespedido_id_seq', 5, true);


--
-- Name: empleados_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.empleados_id_seq', 6, true);


--
-- Name: estadosmesa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.estadosmesa_id_seq', 5, true);


--
-- Name: estadospedido_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.estadospedido_id_seq', 5, true);


--
-- Name: facturas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.facturas_id_seq', 5, true);


--
-- Name: ingredientes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ingredientes_id_seq', 5, true);


--
-- Name: inventario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inventario_id_seq', 5, true);


--
-- Name: mesas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.mesas_id_seq', 6, true);


--
-- Name: pedidos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pedidos_id_seq', 5, true);


--
-- Name: platos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.platos_id_seq', 6, true);


--
-- Name: proveedores_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.proveedores_id_seq', 5, true);


--
-- Name: recetas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.recetas_id_seq', 5, true);


--
-- Name: reservasmesa_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reservasmesa_id_seq', 5, true);


--
-- Name: rolesempleado_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rolesempleado_id_seq', 5, true);


--
-- Name: asignacionesmesa asignacionesmesa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignacionesmesa
    ADD CONSTRAINT asignacionesmesa_pkey PRIMARY KEY (id);


--
-- Name: categoriasplato categoriasplato_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoriasplato
    ADD CONSTRAINT categoriasplato_nombre_key UNIQUE (nombre);


--
-- Name: categoriasplato categoriasplato_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categoriasplato
    ADD CONSTRAINT categoriasplato_pkey PRIMARY KEY (id);


--
-- Name: detallespedido detallespedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallespedido
    ADD CONSTRAINT detallespedido_pkey PRIMARY KEY (id);


--
-- Name: empleados empleados_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT empleados_pkey PRIMARY KEY (id);


--
-- Name: estadosmesa estadosmesa_descripcion_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadosmesa
    ADD CONSTRAINT estadosmesa_descripcion_key UNIQUE (descripcion);


--
-- Name: estadosmesa estadosmesa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadosmesa
    ADD CONSTRAINT estadosmesa_pkey PRIMARY KEY (id);


--
-- Name: estadospedido estadospedido_descripcion_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadospedido
    ADD CONSTRAINT estadospedido_descripcion_key UNIQUE (descripcion);


--
-- Name: estadospedido estadospedido_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.estadospedido
    ADD CONSTRAINT estadospedido_pkey PRIMARY KEY (id);


--
-- Name: facturas facturas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas
    ADD CONSTRAINT facturas_pkey PRIMARY KEY (id);


--
-- Name: ingredientes ingredientes_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingredientes
    ADD CONSTRAINT ingredientes_nombre_key UNIQUE (nombre);


--
-- Name: ingredientes ingredientes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ingredientes
    ADD CONSTRAINT ingredientes_pkey PRIMARY KEY (id);


--
-- Name: inventario inventario_ingrediente_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT inventario_ingrediente_id_key UNIQUE (ingrediente_id);


--
-- Name: inventario inventario_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT inventario_pkey PRIMARY KEY (id);


--
-- Name: mesas mesas_numero_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesas
    ADD CONSTRAINT mesas_numero_key UNIQUE (numero);


--
-- Name: mesas mesas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.mesas
    ADD CONSTRAINT mesas_pkey PRIMARY KEY (id);


--
-- Name: pedidos pedidos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_pkey PRIMARY KEY (id);


--
-- Name: platos platos_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.platos
    ADD CONSTRAINT platos_nombre_key UNIQUE (nombre);


--
-- Name: platos platos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.platos
    ADD CONSTRAINT platos_pkey PRIMARY KEY (id);


--
-- Name: proveedores proveedores_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_nombre_key UNIQUE (nombre);


--
-- Name: proveedores proveedores_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.proveedores
    ADD CONSTRAINT proveedores_pkey PRIMARY KEY (id);


--
-- Name: recetas recetas_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recetas
    ADD CONSTRAINT recetas_pkey PRIMARY KEY (id);


--
-- Name: recetas recetas_plato_id_ingrediente_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recetas
    ADD CONSTRAINT recetas_plato_id_ingrediente_id_key UNIQUE (plato_id, ingrediente_id);


--
-- Name: reservasmesa reservasmesa_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservasmesa
    ADD CONSTRAINT reservasmesa_pkey PRIMARY KEY (id);


--
-- Name: rolesempleado rolesempleado_nombre_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolesempleado
    ADD CONSTRAINT rolesempleado_nombre_key UNIQUE (nombre);


--
-- Name: rolesempleado rolesempleado_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rolesempleado
    ADD CONSTRAINT rolesempleado_pkey PRIMARY KEY (id);


--
-- Name: idx_inventario_ingrediente_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_inventario_ingrediente_id ON public.inventario USING btree (ingrediente_id);


--
-- Name: idx_pedidos_mesa_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_pedidos_mesa_id ON public.pedidos USING btree (mesa_id);


--
-- Name: idx_platos_nombre; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_platos_nombre ON public.platos USING btree (nombre);


--
-- Name: detallespedido trg_actualizar_stock; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_actualizar_stock AFTER INSERT ON public.detallespedido FOR EACH ROW EXECUTE FUNCTION public.fn_actualizar_stock_ingredientes();


--
-- Name: pedidos trg_cambiar_estado_mesa; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_cambiar_estado_mesa AFTER INSERT OR UPDATE ON public.pedidos FOR EACH ROW EXECUTE FUNCTION public.fn_cambiar_estado_mesa();


--
-- Name: pedidos trg_registrar_factura; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_registrar_factura AFTER UPDATE ON public.pedidos FOR EACH ROW WHEN (((new.estado)::text = 'cerrado'::text)) EXECUTE FUNCTION public.fn_registrar_factura();


--
-- Name: asignacionesmesa asignacionesmesa_empleado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignacionesmesa
    ADD CONSTRAINT asignacionesmesa_empleado_id_fkey FOREIGN KEY (empleado_id) REFERENCES public.empleados(id);


--
-- Name: asignacionesmesa asignacionesmesa_mesa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.asignacionesmesa
    ADD CONSTRAINT asignacionesmesa_mesa_id_fkey FOREIGN KEY (mesa_id) REFERENCES public.mesas(id);


--
-- Name: detallespedido detallespedido_pedido_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallespedido
    ADD CONSTRAINT detallespedido_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id);


--
-- Name: detallespedido detallespedido_plato_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.detallespedido
    ADD CONSTRAINT detallespedido_plato_id_fkey FOREIGN KEY (plato_id) REFERENCES public.platos(id);


--
-- Name: empleados empleados_rol_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.empleados
    ADD CONSTRAINT empleados_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES public.rolesempleado(id);


--
-- Name: facturas facturas_pedido_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.facturas
    ADD CONSTRAINT facturas_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos(id);


--
-- Name: inventario inventario_ingrediente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT inventario_ingrediente_id_fkey FOREIGN KEY (ingrediente_id) REFERENCES public.ingredientes(id);


--
-- Name: pedidos pedidos_empleado_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_empleado_id_fkey FOREIGN KEY (empleado_id) REFERENCES public.empleados(id);


--
-- Name: pedidos pedidos_mesa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pedidos
    ADD CONSTRAINT pedidos_mesa_id_fkey FOREIGN KEY (mesa_id) REFERENCES public.mesas(id);


--
-- Name: platos platos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.platos
    ADD CONSTRAINT platos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categoriasplato(id);


--
-- Name: recetas recetas_ingrediente_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recetas
    ADD CONSTRAINT recetas_ingrediente_id_fkey FOREIGN KEY (ingrediente_id) REFERENCES public.ingredientes(id);


--
-- Name: recetas recetas_plato_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.recetas
    ADD CONSTRAINT recetas_plato_id_fkey FOREIGN KEY (plato_id) REFERENCES public.platos(id);


--
-- Name: reservasmesa reservasmesa_mesa_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservasmesa
    ADD CONSTRAINT reservasmesa_mesa_id_fkey FOREIGN KEY (mesa_id) REFERENCES public.mesas(id);


--
-- Name: TABLE asignacionesmesa; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.asignacionesmesa TO gerente;


--
-- Name: TABLE categoriasplato; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.categoriasplato TO gerente;


--
-- Name: TABLE detallespedido; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT,UPDATE ON TABLE public.detallespedido TO camarero;
GRANT SELECT ON TABLE public.detallespedido TO cocinero;
GRANT ALL ON TABLE public.detallespedido TO gerente;


--
-- Name: TABLE empleados; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.empleados TO gerente;


--
-- Name: TABLE estadosmesa; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estadosmesa TO gerente;


--
-- Name: TABLE estadospedido; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.estadospedido TO gerente;


--
-- Name: TABLE facturas; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,UPDATE ON TABLE public.facturas TO cajero;
GRANT ALL ON TABLE public.facturas TO gerente;


--
-- Name: TABLE ingredientes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.ingredientes TO camarero;
GRANT ALL ON TABLE public.ingredientes TO gerente;


--
-- Name: TABLE inventario; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.inventario TO gerente;


--
-- Name: TABLE mesas; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.mesas TO camarero;
GRANT ALL ON TABLE public.mesas TO gerente;


--
-- Name: TABLE pedidos; Type: ACL; Schema: public; Owner: postgres
--

GRANT INSERT,UPDATE ON TABLE public.pedidos TO camarero;
GRANT SELECT ON TABLE public.pedidos TO cocinero;
GRANT ALL ON TABLE public.pedidos TO gerente;


--
-- Name: TABLE platos; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.platos TO camarero;
GRANT ALL ON TABLE public.platos TO gerente;


--
-- Name: TABLE proveedores; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.proveedores TO gerente;


--
-- Name: TABLE recetas; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.recetas TO gerente;


--
-- Name: TABLE reservasmesa; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.reservasmesa TO gerente;


--
-- Name: TABLE rolesempleado; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.rolesempleado TO gerente;


--
-- Name: TABLE vista_ingredientes_bajo_stock; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vista_ingredientes_bajo_stock TO gerente;


--
-- Name: TABLE vista_mesas_libres; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vista_mesas_libres TO gerente;


--
-- Name: TABLE vista_pedidos_por_mesa; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vista_pedidos_por_mesa TO gerente;


--
-- Name: TABLE vista_platos_mas_pedidos; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.vista_platos_mas_pedidos TO gerente;


--
-- PostgreSQL database dump complete
--

