import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import App from "../App";

describe("App", () => {
  it("renders the CloudLab heading", () => {
    render(<App />);
    expect(screen.getByText(/CloudLab/i)).toBeInTheDocument();
  });
});
