const openApiSpec = {
  openapi: "3.0.3",
  info: {
    title: "LifeOS API",
    version: "1.0.0",
    description:
      "API documentation for LifeOS authentication, habits, diary, mood, and budget features.",
  },
  servers: [
    {
      url: "http://localhost:3000",
      description: "Local development server",
    },
  ],
  tags: [
    { name: "Auth" },
    { name: "Habits" },
    { name: "Habit Logs" },
    { name: "Habit Templates" },
    { name: "Budget" },
    { name: "Mood" },
    { name: "Diary" },
    { name: "Questions" },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
    schemas: {
      ErrorResponse: {
        type: "object",
        properties: {
          message: { type: "string" },
        },
      },
      User: {
        type: "object",
        properties: {
          id: { type: "integer", example: 7 },
          first_name: { type: "string", example: "Buse" },
          last_name: { type: "string", example: "Kayan" },
          email: { type: "string", format: "email", example: "buse@example.com" },
        },
      },
      AuthTokens: {
        type: "object",
        properties: {
          accessToken: { type: "string" },
          refreshToken: { type: "string" },
        },
      },
      Habit: {
        type: "object",
        properties: {
          id: { type: "integer" },
          name: { type: "string" },
          description: { type: "string", nullable: true },
          period: { type: "string", example: "morning" },
          frequency_type: { type: "string", example: "weekly" },
          days: {
            type: "array",
            items: { type: "integer" },
            example: [1, 2, 3, 4, 5],
          },
          target_value: { type: "number", nullable: true },
          goal_type: { type: "string", nullable: true, example: "minute" },
        },
      },
      BudgetTransaction: {
        type: "object",
        properties: {
          id: { type: "integer" },
          type: { type: "string", enum: ["income", "expense"] },
          title: { type: "string", example: "Market" },
          amount: { type: "number", example: 450 },
          transaction_date: { type: "string", format: "date" },
          note: { type: "string", nullable: true },
        },
      },
      BudgetSummary: {
        type: "object",
        properties: {
          income_total: { type: "number", example: 5000 },
          expense_total: { type: "number", example: 1200 },
          shared_expense_total: { type: "number", example: 300 },
          remaining_balance: { type: "number", example: 3500 },
        },
      },
      BudgetFriend: {
        allOf: [{ $ref: "#/components/schemas/User" }],
      },
      FriendInvitation: {
        type: "object",
        properties: {
          id: { type: "integer" },
          requester_id: { type: "integer" },
          addressee_id: { type: "integer" },
          status: { type: "string", enum: ["pending", "accepted", "rejected"] },
          first_name: { type: "string" },
          last_name: { type: "string" },
          email: { type: "string", format: "email" },
        },
      },
      SharedExpenseParticipant: {
        allOf: [
          { $ref: "#/components/schemas/User" },
          {
            type: "object",
            properties: {
              share_amount: { type: "number", example: 150 },
            },
          },
        ],
      },
      SharedExpense: {
        type: "object",
        properties: {
          id: { type: "integer" },
          title: { type: "string", example: "Market" },
          amount: { type: "number", example: 300 },
          expense_date: { type: "string", format: "date" },
          paid_by_user: { $ref: "#/components/schemas/User" },
          participants: {
            type: "array",
            items: { $ref: "#/components/schemas/SharedExpenseParticipant" },
          },
        },
      },
      SettlementMemberSummary: {
        allOf: [
          { $ref: "#/components/schemas/User" },
          {
            type: "object",
            properties: {
              paid_amount: { type: "number", example: 300 },
              owed_share: { type: "number", example: 150 },
              balance: { type: "number", example: 150 },
            },
          },
        ],
      },
      DebtSettlement: {
        type: "object",
        properties: {
          from_user: { $ref: "#/components/schemas/User" },
          to_user: { $ref: "#/components/schemas/User" },
          amount: { type: "number", example: 150 },
        },
      },
      SettlementSummary: {
        type: "object",
        properties: {
          members: {
            type: "array",
            items: { $ref: "#/components/schemas/SettlementMemberSummary" },
          },
          settlements: {
            type: "array",
            items: { $ref: "#/components/schemas/DebtSettlement" },
          },
        },
      },
      BudgetGroup: {
        type: "object",
        properties: {
          id: { type: "integer" },
          name: { type: "string", example: "Ev Arkadaşları" },
          created_by: { type: "integer" },
          members: {
            type: "array",
            items: { $ref: "#/components/schemas/BudgetFriend" },
          },
          expenses: {
            type: "array",
            items: { $ref: "#/components/schemas/SharedExpense" },
          },
          settlement_summary: {
            $ref: "#/components/schemas/SettlementSummary",
          },
        },
      },
    },
    responses: {
      Unauthorized: {
        description: "Missing or invalid JWT token",
        content: {
          "application/json": {
            schema: { $ref: "#/components/schemas/ErrorResponse" },
          },
        },
      },
      ValidationError: {
        description: "Invalid request data",
        content: {
          "application/json": {
            schema: { $ref: "#/components/schemas/ErrorResponse" },
          },
        },
      },
    },
  },
  paths: {
    "/users/register": {
      post: {
        tags: ["Auth"],
        summary: "Register a new user",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["first_name", "last_name", "email", "password"],
                properties: {
                  first_name: { type: "string", example: "Buse" },
                  last_name: { type: "string", example: "Kayan" },
                  email: {
                    type: "string",
                    format: "email",
                    example: "buse@example.com",
                  },
                  password: { type: "string", format: "password" },
                },
              },
            },
          },
        },
        responses: {
          201: { description: "User registered successfully" },
          400: { $ref: "#/components/responses/ValidationError" },
        },
      },
    },
    "/users/login": {
      post: {
        tags: ["Auth"],
        summary: "Log in and receive tokens",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "buse@example.com",
                  },
                  password: { type: "string", format: "password" },
                },
              },
            },
          },
        },
        responses: {
          200: {
            description: "Login successful",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthTokens" },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/users/me": {
      get: {
        tags: ["Auth"],
        summary: "Get the authenticated user",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Authenticated user",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/User" },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/habits": {
      get: {
        tags: ["Habits"],
        summary: "List habits for the authenticated user",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "date",
            in: "query",
            schema: { type: "string", format: "date" },
          },
        ],
        responses: {
          200: {
            description: "Habit list",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    habits: {
                      type: "array",
                      items: { $ref: "#/components/schemas/Habit" },
                    },
                  },
                },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
      post: {
        tags: ["Habits"],
        summary: "Create a habit",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: { $ref: "#/components/schemas/Habit" },
            },
          },
        },
        responses: {
          201: { description: "Habit created" },
          400: { $ref: "#/components/responses/ValidationError" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/habits/{id}": {
      delete: {
        tags: ["Habits"],
        summary: "Delete a habit",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/HabitId" }],
        responses: {
          200: { description: "Habit deleted" },
          404: { description: "Habit not found" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/habit-logs/toggle": {
      post: {
        tags: ["Habit Logs"],
        summary: "Toggle a checkbox habit log",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["habitId", "date"],
                properties: {
                  habitId: { type: "integer" },
                  date: { type: "string", format: "date" },
                },
              },
            },
          },
        },
        responses: {
          200: { description: "Habit log toggled" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/habit-logs/value": {
      patch: {
        tags: ["Habit Logs"],
        summary: "Update a goal-based habit log value",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["habitId", "date", "value"],
                properties: {
                  habitId: { type: "integer" },
                  date: { type: "string", format: "date" },
                  value: { type: "number" },
                },
              },
            },
          },
        },
        responses: {
          200: { description: "Habit log value updated" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/habit-templates": {
      get: {
        tags: ["Habit Templates"],
        summary: "List habit templates",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Template list" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/habit-templates/{id}/add": {
      post: {
        tags: ["Habit Templates"],
        summary: "Add a habit template to the user's habits",
        security: [{ bearerAuth: [] }],
        parameters: [{ $ref: "#/components/parameters/TemplateId" }],
        responses: {
          201: { description: "Template added" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/budget/transactions": {
      get: {
        tags: ["Budget"],
        summary: "List monthly personal budget transactions",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "month",
            in: "query",
            required: true,
            schema: { type: "string", pattern: "^\\d{4}-\\d{2}$" },
            example: "2026-06",
          },
        ],
        responses: {
          200: {
            description: "Monthly budget transactions and summary",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    summary: { $ref: "#/components/schemas/BudgetSummary" },
                    transactions: {
                      type: "array",
                      items: { $ref: "#/components/schemas/BudgetTransaction" },
                    },
                  },
                },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
      post: {
        tags: ["Budget"],
        summary: "Create a personal budget transaction",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["type", "title", "amount", "transaction_date"],
                properties: {
                  type: { type: "string", enum: ["income", "expense"] },
                  title: { type: "string", example: "Market" },
                  amount: { type: "number", example: 450 },
                  transaction_date: { type: "string", format: "date" },
                  note: { type: "string", nullable: true },
                },
              },
            },
          },
        },
        responses: {
          201: { description: "Transaction created" },
          400: { $ref: "#/components/responses/ValidationError" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/budget/friends": {
      get: {
        tags: ["Budget"],
        summary: "List accepted budget friends",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Accepted friends",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    friends: {
                      type: "array",
                      items: { $ref: "#/components/schemas/BudgetFriend" },
                    },
                  },
                },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/budget/friend-invitations": {
      get: {
        tags: ["Budget"],
        summary: "List incoming pending friend invitations",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Incoming invitations",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    invitations: {
                      type: "array",
                      items: { $ref: "#/components/schemas/FriendInvitation" },
                    },
                  },
                },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
      post: {
        tags: ["Budget"],
        summary: "Send a friend invitation",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "ece@example.com",
                  },
                },
              },
            },
          },
        },
        responses: {
          201: { description: "Invitation sent" },
          409: { description: "Invitation already pending or accepted" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/budget/friend-invitations/{id}/respond": {
      post: {
        tags: ["Budget"],
        summary: "Accept or reject a friend invitation",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "integer" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["action"],
                properties: {
                  action: { type: "string", enum: ["accept", "reject"] },
                },
              },
            },
          },
        },
        responses: {
          200: { description: "Invitation updated" },
          404: { description: "Invitation not found" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/budget/groups": {
      get: {
        tags: ["Budget"],
        summary: "List shared budget groups with expenses and settlements",
        security: [{ bearerAuth: [] }],
        responses: {
          200: {
            description: "Shared budget groups",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    groups: {
                      type: "array",
                      items: { $ref: "#/components/schemas/BudgetGroup" },
                    },
                  },
                },
              },
            },
          },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
      post: {
        tags: ["Budget"],
        summary: "Create a shared budget group",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name", "memberIds"],
                properties: {
                  name: { type: "string", example: "Ev Arkadaşları" },
                  memberIds: {
                    type: "array",
                    items: { type: "integer" },
                    example: [12, 13],
                  },
                },
              },
            },
          },
        },
        responses: {
          201: { description: "Group created" },
          400: { $ref: "#/components/responses/ValidationError" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/budget/groups/{groupId}/expenses": {
      post: {
        tags: ["Budget"],
        summary: "Create a shared expense split between selected participants",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "groupId",
            in: "path",
            required: true,
            schema: { type: "integer" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["title", "amount", "expense_date", "participant_ids"],
                properties: {
                  title: { type: "string", example: "Market" },
                  amount: { type: "number", example: 300 },
                  expense_date: { type: "string", format: "date" },
                  participant_ids: {
                    type: "array",
                    items: { type: "integer" },
                    example: [7, 12],
                  },
                },
              },
            },
          },
        },
        responses: {
          201: {
            description: "Shared expense created",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    expense: { $ref: "#/components/schemas/SharedExpense" },
                  },
                },
              },
            },
          },
          400: { $ref: "#/components/responses/ValidationError" },
          403: { description: "User is not allowed to modify this group" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/moods": {
      get: {
        tags: ["Mood"],
        summary: "Get mood entry",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Mood entry" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
      post: {
        tags: ["Mood"],
        summary: "Create or update mood entry",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Mood saved" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/moods/month": {
      get: {
        tags: ["Mood"],
        summary: "List mood entries for a month",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            in: "query",
            name: "year",
            required: true,
            schema: { type: "integer", example: 2026 },
          },
          {
            in: "query",
            name: "month",
            required: true,
            schema: { type: "integer", minimum: 1, maximum: 12, example: 6 },
          },
        ],
        responses: {
          200: {
            description: "Monthly mood entries",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    moods: {
                      type: "array",
                      items: {
                        type: "object",
                        properties: {
                          mood: {
                            type: "string",
                            enum: [
                              "mutlu",
                              "sakin",
                              "enerjik",
                              "uzgun",
                              "stresli",
                              "yorgun",
                            ],
                          },
                          log_date: { type: "string", format: "date" },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
          400: { $ref: "#/components/responses/ValidationError" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/diaries": {
      get: {
        tags: ["Diary"],
        summary: "List diary entries",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Diary entries" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
      post: {
        tags: ["Diary"],
        summary: "Create a diary entry",
        security: [{ bearerAuth: [] }],
        responses: {
          201: { description: "Diary entry created" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
    "/questions/daily-questions": {
      get: {
        tags: ["Questions"],
        summary: "List daily reflection questions",
        security: [{ bearerAuth: [] }],
        responses: {
          200: { description: "Daily questions" },
          401: { $ref: "#/components/responses/Unauthorized" },
        },
      },
    },
  },
};

openApiSpec.components.parameters = {
  HabitId: {
    name: "id",
    in: "path",
    required: true,
    schema: { type: "integer" },
  },
  TemplateId: {
    name: "id",
    in: "path",
    required: true,
    schema: { type: "integer" },
  },
};

module.exports = openApiSpec;
