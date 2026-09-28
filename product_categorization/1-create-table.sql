BEGIN;

CREATE TABLE public.product_attribute_hierarchy_condition (
    id integer PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    product_attribute_enum_value_id integer NOT NULL
        REFERENCES public.product_attribute_enum_value(id),
    product_attribute_enum_hierarchy_id integer NOT NULL
        REFERENCES public.product_attribute_enum_hierarchy(id),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    UNIQUE (product_attribute_enum_value_id, product_attribute_enum_hierarchy_id)
);

CREATE INDEX idx_product_attribute_hierarchy_condition_enum_value
    ON public.product_attribute_hierarchy_condition (product_attribute_enum_value_id);

COMMIT;
