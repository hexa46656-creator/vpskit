import { useEffect, useState } from "react";

import {
  fetchHealth,
  fetchRuntimeServices,
  type HealthStatus,
  type RuntimeService,
} from "./api";

type ServiceState = "configured" | "pending" | "error";

type Service = {
  name: string;
  state: ServiceState;
  detail: string;
};

const fallbackServices: Service[] = [
  {
    name: "API",
    state: "configured",
    detail: "FastAPI backend skeleton is ready for local development.",
  },
  {
    name: "Subscription renderer",
    state: "configured",
    detail: "Profiles can be rendered by the backend package.",
  },
  {
    name: "Deployment",
    state: "pending",
    detail: "Docker and VPS scripts are intentionally not included yet.",
  },
];

function normalizeService(service: RuntimeService): Service {
  return {
    name: service.name,
    state: service.state === "configured" ? "configured" : "pending",
    detail: service.detail,
  };
}

export default function App() {
  const [health, setHealth] = useState<HealthStatus | null>(null);
  const [services, setServices] = useState<Service[]>(fallbackServices);
  const [apiMessage, setApiMessage] = useState(
    "Backend not checked yet; showing local sample data.",
  );

  useEffect(() => {
    let isMounted = true;

    async function loadBackendStatus() {
      try {
        const [healthStatus, runtimeServices] = await Promise.all([
          fetchHealth(),
          fetchRuntimeServices(),
        ]);

        if (!isMounted) {
          return;
        }

        setHealth(healthStatus);
        setServices(runtimeServices.map(normalizeService));
        setApiMessage("Connected to the FastAPI backend.");
      } catch {
        if (!isMounted) {
          return;
        }

        setHealth(null);
        setServices(fallbackServices);
        setApiMessage("Backend unavailable; showing local sample data.");
      }
    }

    void loadBackendStatus();

    return () => {
      isMounted = false;
    };
  }, []);

  return (
    <main className="app-shell">
      <section className="hero">
        <p className="eyebrow">VPSKit</p>
        <h1>VPS automation control panel</h1>
        <p>
          A compact starting point for managing runtime health, subscription
          output, and future deployment workflows.
        </p>
        <p className="api-status">
          {apiMessage}
          {health ? ` Environment: ${health.environment}.` : ""}
        </p>
      </section>

      <section className="service-list" aria-label="Service status">
        {services.map((service) => (
          <article className="service-card" key={service.name}>
            <div>
              <h2>{service.name}</h2>
              <p>{service.detail}</p>
            </div>
            <span className={`status status-${service.state}`}>
              {service.state}
            </span>
          </article>
        ))}
      </section>
    </main>
  );
}
