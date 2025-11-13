import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  // Ensure static files are properly served
  experimental: {
    outputFileTracingIncludes: {
      "/**": [".next/static/**/*"],
    },
  },
};

export default nextConfig;
